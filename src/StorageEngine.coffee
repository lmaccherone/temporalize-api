HashRing = require('hashring')
crypto = require('crypto')
zxcvbn = require('zxcvbn')
path = require('path')
{WrappedClient, getLink, getDocLink, _, async, getGUID, sqlFromMongo} = require('documentdb-utils')

module.exports = class StorageEngine
  ###


  
  ###

  constructor: (userConfig, callback) ->
    ###

    ###
    unless userConfig?
      userConfig = {}
    config = JSON.parse(JSON.stringify(userConfig))  # Make a clone

    # Set defaults
    @topLevelPartitionField = config.topLevelPartitionField or '_TenantID'
    @secondLevelPartitionField = config.secondLevelPartitionField or '_EntityID'
    @firstTopLevelID = config.firstTopLevelID or 'A'
    @firstSecondLevelID = config.firstSecondLevelID or '001'
    @temporalPolicy = config.temporalPolicy or 'VALID_TIME'
    @refreshConfigMS = config.refreshConfigMS or 10000
    @debug = config.debug or false
    @terminate = config.terminate or false  # This is useful for testing. In general though you should call stop()
    @readConfigContinuouslyEventHandler = config.readConfigContinuouslyEventHandler or null
    @cacheSelfLinks = config.cacheSelfLinks or false
    @sessionTTL = config.sessionTTL or 30 * 60 * 1000  # 30 minutes

    @ongoingTransactions = {}
    @secondLevelHashring = null
    @linkCache = {}
    @lastTimeConfigWasRead = new Date()
    @sessionCacheByID = {}
    @sessionCacheByUsername = {}
    @_purgeSessionsContinuously()

    @HIGHEST_DATE_STRING = '9999-01-01T00:00:00.000Z'
    @LOWEST_DATE_STRING = '0001-01-01T00:00:00.000Z'
    @SYSTEM_FIELDS = ["id", "_ValidFrom", "_ValidTo", "_EntityID", "_TenantID", "_CreationTransactionID", "_UpdateTransactionID", "_PreviousValues"]

    @readConfigRetries = 0
#    @lastTimeConfigWasRead = new Date()

    # Get client
    if config.wrappedClient?
      @client = wrappedClient
    else
      if config.client?
        @_client = config.client
        new WrappedClient(@_client)
      else
        @client = new WrappedClient()

    @_initializeDatabase(callback)

  _initializeDatabase: (callback) ->
    # Unless it already exists, create first database
    @_debug("Checking existence or creating database: #{@firstTopLevelID}")
    @client.createDatabase({id: @firstTopLevelID}, (err, response) =>
      if err? and err.code isnt 409
        throw new Error(JSON.stringify(err))
      else
        if err?.code is 409
          @_debug("Database already existed")
        else
          @_debug("Created Database. Response:", response)

        # Unless it already exists, create first collection
        databaseIDLink = getLink(@firstTopLevelID)
        if response?
          @linkCache[databaseIDLink] = response._self
          databaseLink = response._self
        else
          databaseLink = databaseIDLink
        @client.createCollection(databaseLink, {id: @firstSecondLevelID}, (err, response) =>
          if err? and err.code isnt 409
            throw new Error(JSON.stringify(err))
          else
            @_debug("Created Collection. Response:", response)
            collectionIDLink = getLink(@firstTopLevelID, @firstSecondLevelID)
            if response?
              @linkCache[collectionIDLink] = response._self
            @_readOrCreateInitialConfig((err, response, headers) =>
              username = process.env.TEMPORALIZE_USERNAME
              password = process.env.TEMPORALIZE_PASSWORD
              if username? and password?
                query = {username}
                @_query({query, asOf: 'LATEST'}, (err, users, userHeaders) =>
                  if err?
                    callback({code: 400, body: "Got error trying to retrieve user: #{username}"})
                    return
                  else
                    if users.length is 1
                      callback(err, response, headers)
                    else if users.length > 1
                      callback({code: 400, body: "Got more than one asOf='LATEST' row for user: #{username}"})
                      return
                    else
                      superUser =
                        username: username
                        _IsTemporalizeSuperUser: true
                        _TenantID: 'temporalize-admin'
                        _EntityID: 'temporalize-super-user'
                      @_upsertUser(superUser, password, (err, superUserResponse) =>
                        if err?
                          callback(err)
                        callback(err, response, headers)
                      )
                )
              else
                callback(err, response, headers)
            )
        )
    )


  initializeDatabase: (username, password, callback) ->
    if username is process.env.TEMPORALIZE_USERNAME and password is process.env.TEMPORALIZE_PASSWORD
        @_initializeDatabase(callback)
    else
      callback({code: 401, body: "Invalid login"})

  deleteDatabase: (username, password, databaseID, callback) ->
    if username is process.env.TEMPORALIZE_USERNAME and password is process.env.TEMPORALIZE_PASSWORD
      @client.deleteDatabase(getLink(databaseID), callback)
    else
      callback({code: 401, body: "Invalid login"})

  _delay = (ms, func) ->
    setTimeout(func, ms)

  _debug: (message, content, content2) ->
    # TODO: Add logging here. Current favorite is https://github.com/trentm/node-bunyan
    if @debug
      console.log(message)
      if content?
        console.log(JSON.stringify(content, null, 2))
        console.log()
      if content2?
        console.log(JSON.stringify(content2, null, 2))
        console.log()

  _handleIfError: (err, callback) ->
    if err?
      @_debug('ERROR', err)
      if callback?
        callback(err)
      return
    else
      return false

  _readConfig: (callback) =>
    @client.readDocument(getDocLink(@firstTopLevelID, @firstSecondLevelID, 'storage-engine-config'), (err, response, header) =>
      if err?
        callback(err)
      else
        @storageEngineConfig = response
        @readConfigRetries = 0
        @lastTimeConfigWasRead = new Date()
        @_debug('Successfully retrieved @storageEngineConfig', @storageEngineConfig, header)
        callback(@storageEngineConfig)
    )

  _readConfigContinuously: () =>
    unless @terminate
      if (new Date() - @lastTimeConfigWasRead) > @refreshConfigMS
        @_readConfig((nullOrConfig) =>
          setTimeout(@_readConfigContinuously, @refreshConfigMS)
          if nullOrConfig?
            if @readConfigContinuouslyEventHandler?
              @readConfigContinuouslyEventHandler(nullOrConfig)
        )
      else
        setTimeout(@_readConfigContinuously, @refreshConfigMS)

  _purgeSessionsContinuously: () =>
    # TODO: Make this work against sessions stored in DocumentDB or wait unitl DocumentDB has TTL
    unless @terminate
      for id, session of @sessionCacheByID
        sessionTTL = session.user.sessionTTL or @sessionTTL
        if new Date() - new Date(session._Created) >= sessionTTL
          delete @sessionCacheByID[id]
          delete @sessionCacheByUsername[session.user.username]
      setTimeout(@_purgeSessionsContinuously, @refreshConfigMS)  # TODO: Maybe increase this to @sessionTTL, but that would make testing harder because the callback might not happen for 30 minutes.

  _readOrCreateInitialConfig: (callback) =>
    @client.readDocument(getDocLink(@firstTopLevelID, @firstSecondLevelID, 'storage-engine-config'), (err, response, header) =>
      if err? and err.code is 404  # Not found so creating default config
        @_debug("#{getDocLink(@firstTopLevelID, @firstSecondLevelID, 'storage-engine-config')} not found. Creating a default config", header)
        secondLevelPartitions = {}
        secondLevelPartitions[@firstSecondLevelID] = {id: @firstSecondLevelID}
        topLevelPartitions = {}
        topLevelPartitions[@firstTopLevelID] = {id: @firstTopLevelID, secondLevelPartitions}
        partitionConfig = {topLevelPartitions, topLevelLookupMap: {'default': @firstTopLevelID}}
        @storageEngineConfig =
          id: 'storage-engine-config',  # There is only one of these so we've hard-coded the id.
          mode: 'RUNNING',
          lastValidFrom: @LOWEST_DATE_STRING,
          partitionConfig: partitionConfig
        @_debug('Setting @storageEngineConfig', @storageEngineConfig)
        @_writeConfig(() =>
          @_readConfigContinuously()
          callback()
        )
      else if err?
        callback(err)
        return
      else
        @storageEngineConfig = response
        @_debug('Successfully retrieved @storageEngineConfig', @storageEngineConfig, header)
        @lastTimeConfigWasRead = new Date()
        @_readConfigContinuously()
        if callback?
          callback(null, @storageEngineConfig, header)
    )

  _writeConfig: (retriesLeft, callback) =>
    unless callback?
      callback = retriesLeft
      retriesLeft = null
    unless retriesLeft?
      retriesLeft = 3
    @client.upsertDocument(getLink(@firstTopLevelID, @firstSecondLevelID), @storageEngineConfig, (err, response, header) =>
      if err?
        callback(err)
        return
      else
        @_debug('Success: wrote @storageEngineConfig to database', response, header)
        if callback?
          callback()
    )

  _resolveToListOfPartitions: (topLevelPartitionKey, secondLevelPartitionKey, originalPartitionConfig) ->
    # returns a list of second-level partitions as an array of collection links
    # TODO: When mode is 'BALANCING', add ones specified by oldPartitionConfig
    partitions = []
    if originalPartitionConfig?
      partitionConfig = originalPartitionConfig
    else
      partitionConfig = @storageEngineConfig.partitionConfig
    topLevelLookupMap = partitionConfig.topLevelLookupMap
    topLevelPartitions = partitionConfig.topLevelPartitions
    if topLevelPartitionKey?
      databaseID = topLevelLookupMap[topLevelPartitionKey]
      unless databaseID?
        databaseID = topLevelLookupMap['default']
      topLevelPartition = topLevelPartitions[databaseID]
      if secondLevelPartitionKey?  # Get just the one
        if originalPartitionConfig?
          hashring = new HashRing(topLevelPartition.secondLevelPartitions)
        else if not @secondLevelHashring?.get?
          @secondLevelHashring = new HashRing(topLevelPartition.secondLevelPartitions)
          hashring = @secondLevelHashring
        else
          hashring = @secondLevelHashring
        collectionID = hashring.get(secondLevelPartitionKey)
        partitions.push(getLink(databaseID, collectionID))
      else
        for collectionID of topLevelPartition.secondLevelPartitions
          partitions.push(getLink(databaseID, collectionID))
    else # Get them all
      for databaseID, topLevelPartition of topLevelPartitions
        for collectionID of topLevelPartition.secondLevelPartitions
          partitions.push(getLink(databaseID, collectionID))

    return partitions

# Don't delete these functions below until we are sure that we can use id-based links

#  _getLink: (databaseID, collectionID, documentID) ->
#    utils.assert(databaseID?, "_getLink must be called with at least a databaseID")
#    idLink = getLink(databaseID, collectionID, documentID)
#    if documentID? or not @cacheSelfLinks
#      return idLink
#
#    if @linkCache[idLink]?
#      return @linkCache[idLink]
#    else
#      if collectionID?
#        @client.readCollection(idLink, @_getSelfLinkHandler(idLink, this))
#      else
#        @client.readDatabase(idLink, @_getSelfLinkHandler(idLink, this))
#      return idLink  # Returning this now for responsiveness.

#  _getSelfLinkHandler: (idLink, se) ->
#    f = (err, response, header) ->
#      if err?
#        # Do nothing. Worst case, it'll cache the link next time.
#      else
#        se._debug("Got self link fetcher response: #{idLink} = #{response._self}")
#        se.linkCache[idLink] = response._self
#
#    return f

  stop: (callback) ->  # POST /stop
    ###

    ###
    @storageEngineConfig.mode = 'STOPPED'
    @_writeConfig(callback)
    # Every servo maintains, @storage-engine-config in memory
    # Every servo reads the storage-engine-config document every 10 seconds
    # Every handler except the admin handler checks @storage-engine-config. Respond appropriately if mode isnt 'RUNNING'
    # Wait 30-90 seconds, then callback({modeChanged: "storage engine is STOPPED."}) which I assume will be logged.

  start: (callback) ->  # POST /start
    # Read storage-engine-config
    # If storage-engine-config is missing, then create one with firstDatabase and firstCollection and mode = 'STOPPED'
    # If storage-engine-config.mode is 'BALANCING'
    #   goto restartBalancing
    # else
    #   Set storage-engine-config.mode = 'RUNNING'
    #   Wait 10 seconds, then callback({modeChanged: "storage engine is RUNNING."}) which I assume will be logged.

  addCollections: (callback) ->  # POST /add-collections {body: {count: 2}} Default is {count: 1}
    # Fetch current collectionList and store copy in newPartitionConfig
    # Confirm that the existing ones are all numbers in order
    # Add n to the end of the newPartitionConfig
    # Call updateCollectionList with {body: newPartitionConfig}

  updatePartitionConfig: (msBetweenPages = 0, callback) ->  # POST /update-partition-config {body: <new partition config>}
    ###
    Apparently continuation tokens stick around for days so we can take a long time to crawl through one collection.
    ###

    # Throw an error if there is an existing balancing ongoing
    # Call stopHandler. Don't proceed until it finishes (callback).
    # oldCollectionList = @storage-engine-config.collectionList
    # Calculate databasesToRemove as the ones that are in old list but not new list,
    #   databasesToAdd as the ones that are in the new list but not the old list, and
    #   allDatabases as the union of both lists.
    # Calculate collectionsToRemove as the ones that are in old list but not new list,
    #   collectionsToAdd as the ones that are in the new list but not the old list, and
    #   allCollections as the union of both lists.
    # If collectionsToRemove includes {firstDatabase, firstCollection}, then throw an error
    
    # For each databasesToAdd, create them, unless they already exist
    # For each collectionsToAdd, create them, unless they already exist
    
    # oldCollectionResolver = @collectionResolver
    # collectionResolver = new ConsistentHashing(newPartitionConfig)
    # Set storage-engine-config.mode = 'BALANCING'
    # Set storage-engine-config.oldPartitionConfig = partitionConfig
    # Set storage-engine-config.collection = newPartitionConfig
    # Write storage-engine-config

    # Wait 30-90 seconds
    # Call restartBalancing(msBetweenPages, callback)

  restartBalancing: (msBetweenPages = 0, callback) ->  # POST /restart-balancing
    ###
    The pseudo-code below is shown as loops, but we want to pick up each and every page as if it's restarting,
    so it'll recursive calls to this handler for each page. If it crashes, then there will be a part of the last
    page that's only partially done. It'll redo the page and find that only the documents that hadn't already moved
    are all that's left. If it crashes between the write and the delete, then the same id will be in two collections.
    However, when it restarts, and we go to write the duplicate to the new location, we'll reuse the id so there
    is no chance of creating duplicates in the same collection. Worst case, we'll need to swallow the duplicate id error
    so the delete can proceed. However, any reads that occur before it's deleted, will return the same row twice.
    ###

    # If mode isnt 'BALANCING', throw "Cannot restart balancing because mode isnt "BALANCING"
    # For each oldCollectionList
    #   Set storage-engine-config.currentlBalancingCollection to {database, collection}
    #   For each page
    #     For each document in page
    #       if oldCollectionResolver(doc[secondLevelPartitionField]) <> collectionResolver(oc[secondLevelPartitionField])
    #         write document to new collection
    #         delete document from old collection
    #     Set storage-engine-config.currentBalancingContinuationToken

    # Once there are no more collections
    # Set mode = 'STOPPED'
    # Save storage-engine-config
    # Wait 30-90 seconds

    # Call startHandler

  upsert: (sessionID, upserts, temporalPolicy = @temporalPolicy, callback) =>  # POST /upsert-entity {body: <entity field updates>}
    ###
    This is a true incremental update. It will start with the most recent version of this entity and apply the field
    changes specified in the upsert call. If you want to remove a field, you must specify that field as null.
    Note, the null values are not stored so keep that in mind when composing queries.
    In general, you'll want to use {<fieldName>: $exists} rather than {$not: {<fieldName>: $isNull}}.

    The default temporalPolicy can be overridden for each call to upsertEntity. If there is an entity type that you don't
    want history for but others where you do, then you can control that on calls to upsert. Be careful to be consistent within
    an entity type. More commonly the temporalPolicy is set for the entire system during instantiation.

    Depending upon the temporalPolicy, entities are annotated with the Temporalize _ValidFrom/_ValidTo Richard Snodgrass
    mono-temporal data model.

    Note, transaction support for when _TemporalPolicy is 'NONE' is implemented by maintaining the _ValidFrom and _ValidTo
    fields just as it would for when it's not 'NONE', however, a 30-90 second delay is set to come back and delete
    the old version. This means that there are 30-90 seconds where two version of the entity exist. So, queries
    against these sort of entities should be made with asOf = 'LATEST'. No effort is made to enforce this except
    when the global @temporalPolicy is set to 'NONE'. In that case, the default for asOf on queries becomes 'LATEST'.
    ###
    if sessionID?
      @_getSession(sessionID, (err, session) =>
        for upsert in upserts
          unless session.user._IsTemporalizeSuperUser or upsert[@topLevelPartitionField] in session.user.tenantIDsICanWrite
            transactionHandler({
              code: 401,
              body: "User with username: #{session.user.username} does not have permission to write to tenant with id: #{upsert[@topLevelPartitionField]}"
            })
            return
        @_upsert(upserts, temporalPolicy, callback)
      )
    else
      transactionHandler({code: 401, body: "Missing sessionID"})

  _upsert: (upserts, temporalPolicy = @temporalPolicy, callback) =>
    unless @terminate
      unless callback?
        callback = temporalPolicy
        temporalPolicy = null
      unless temporalPolicy?
        temporalPolicy = @temporalPolicy

      unless _.isArray(upserts)
        upserts = [upserts]

      @_readConfig(() =>
        t = new Date().toISOString()
        if t > @storageEngineConfig.lastValidFrom
          transactionTimeString = t
        else
          transactionTimeString = new Date(new Date(@storageEngineConfig.lastValidFrom).valueOf() + 1).toISOString()
        transactionID = getGUID()
        transaction = {id: transactionID, callback, requestCount: 0, responseCount: 0, transactionTimeString, se: this}
        transactionHandler = @_getTransactionHandler(transaction)
        transaction.transactionHandler = transactionHandler
        transaction.entityIDsForThisTransaction = []

        for upsert in upserts
          @_upsertOne(upsert, transaction)
      )

  _upsertOne: (upsert, transaction) =>
#          if upsert._IsTemporalizeUser  # TODO: Somehow prevent updates to _IsTemoralizeUser without going through upsertUser
#            break
    transactionHandler = transaction.transactionHandler
    unless upsert[@topLevelPartitionField]?
      transactionHandler({code: 400, body: "Every row in upserts must have a #{@topLevelPartitionField} field"})
      return
    unless upsert[@secondLevelPartitionField]?
      transactionHandler({code: 400, body: "Every row in upserts must have a #{@secondLevelPartitionField} field"})
      return
    if upsert[@secondLevelPartitionField] in transaction.entityIDsForThisTransaction
      transactionHandler({code: 400, body: "#{@secondLevelPartitionField} must be not be duplicated in upsert list"})
      return
    else
      transaction.entityIDsForThisTransaction.push(upsert[@secondLevelPartitionField])

    upsert._CreationTransactionID = transaction.id
    upsert._ValidFrom = transaction.transactionTimeString
    upsert._ValidTo = @HIGHEST_DATE_STRING

    query = {_ValidTo: @HIGHEST_DATE_STRING}
    query[@secondLevelPartitionField] = upsert[@secondLevelPartitionField]
#    queryString = sqlFromMongo(queryObject, 'c', '*')
    querySpec = {query}
    partitionList = @_resolveToListOfPartitions(upsert[@topLevelPartitionField], upsert[@secondLevelPartitionField])
    if partitionList.length isnt 1
      transactionHandler({code: 403, body: "ERROR: partitionList.length for upsert() call should be 1. It is: #{partitionList.length}"})
      return
    collectionLink = partitionList[0]
    @_debug("Looking for documents with existing _EntityID with: `#{JSON.stringify(querySpec)}`")
    @client.queryDocuments(collectionLink, querySpec).toArray((err, response, header) =>
      if err?
        transactionHandler({code: err.code, body: "Got '#{err.body}' calling @client.queryDocuments() from within upsert"})
        return
      else  # No err
        if response.length > 1
          transactionHandler({code: 403, body: "Got more than one document with _ValidTo = #{@HIGHEST_DATE_STRING} for #{@secondLevelPartitionField} = #{upsert[@secondLevelPartitionField]}"})
          return
        else if response.length is 1  # Found an old version of this entity. Upgrade.
          # TODO: If none of the fields are different, do nothing
          @_debug("Found old version for #{@secondLevelPartitionField}: #{upsert[@secondLevelPartitionField]}.")
          oldVersion = response[0]
          newVersion = JSON.parse(JSON.stringify(oldVersion))
          delete newVersion.id
          newVersion._PreviousValues = {}
          nothingChanged = true
          for key, value of upsert
            if upsert[key]?  # This is intentionally not value? because value might be null
              newVersion[key] = value
              if value isnt oldVersion[key]
                nothingChanged = false
            else
              delete newVersion[key]
            # Set previous values. TODO: Upgrade to support deep references _PreviousValues: {'rootField.subField': 'old value'} Probably a bad idea to support arrays as they could be large
            unless key in @SYSTEM_FIELDS
              unless JSON.stringify(oldVersion[key]) is JSON.stringify(newVersion[key])
                if oldVersion[key]?
                  newVersion._PreviousValues[key] = oldVersion[key]
                else
                  newVersion._PreviousValues[key] = null
          if nothingChanged
            transactionHandler(null, oldVersion)
          else
            @client.createDocument(collectionLink, newVersion, (err, response, header) =>
              if err?
                transactionHandler({code: err.code, body: "Got '#{err.body}' calling @client.createDocument() from within upsert"})
                return
              else
                newDocument = response
                @_debug("Done writing new version for #{@secondLevelPartitionField}: #{upsert[@secondLevelPartitionField]}. Starting to update old version.")
                oldVersion._ValidTo = transaction.transactionTimeString
                oldVersion._UpdateTransactionID = transaction.id
                requestOptions = {accessCondition: {type: 'IfMatch', condition: oldVersion._etag}}
                documentLink = collectionLink + "/docs/#{oldVersion.id}"
                transaction.requestCount++
                @client.replaceDocument(documentLink, oldVersion, requestOptions, transactionHandler)
            )

        else  # No old version. Just need to add.
          @_debug("No old version for #{@secondLevelPartitionField}: #{upsert[@secondLevelPartitionField]}. Just need to add.")
          upsertCopy = JSON.parse(JSON.stringify(upsert))
          upsertCopy._PreviousValues = {}
          for key, value of upsertCopy
            unless key in @SYSTEM_FIELDS
              if value?
                upsertCopy._PreviousValues[key] = null
          transaction.requestCount++
          @client.createDocument(collectionLink, upsertCopy, transactionHandler)
    )

  upsertUser: (sessionID, user, password, callback) =>  # GET /upsert-user
    # You can either provide the password as a field inside the user entity or as a seperate parameter
    # Since Temporalize owns this entity type, the temporalPolicy is always 'VALID_TIME'
    unless callback?
      callback = password
    unless user.tenantIDsICanAdmin?
      user.tenantIDsICanAdmin = []
    unless user.tenantIDsICanRead?
      user.tenantIDsICanRead = []
    unless user.tenantIDsICanWrite?
      user.tenantIDsICanWrite = []
    delete user._IsTemporalizeSuperUser  # Super users can only be created by calling _upsertUser or writing directly to the database
    if sessionID?
      @_getSession(sessionID, (err, session) =>
        if session.user._IsTemporalizeSuperUser or user[@topLevelPartitionField] in session.user.tenantIDsICanWrite
          @_upsertUser(user, password, callback)
        else
          callback({
            code: 401,
            body: "User with username: #{session.user.username} does not have permission to write to tenant with id: #{user[@topLevelPartitionField]}"
          })
          return
    )
    else
      callback({
        code: 401,
        body: "Missing sessionID"
      })

  _upsertUser: (user, password, callback) =>
    unless callback?
      callback = password
    if user.password?
      password = user.password
      # TODO: Add fields from the user to the second parameter (user dictionary) in the call to zxcvbn
      passwordStrength = zxcvbn(password)
      if passwordStrength.score < 2
        callback({code: 400, body: "Password is too weak. #{passwordStrength.feedback.warning}."})
        return
      else
        delete user.password
    user._IsTemporalizeUser = true

    # Clear session caches for this user
    # TODO: Figure out how to clear caches on other servos? Consider updating them instead of deleting them.
    session = @sessionCacheByUsername[user.username]
    if session?
      delete @sessionCacheByUsername[user.username]
      delete @sessionCacheByID[session.id]
    if password?
      user.salt = crypto.randomBytes(128).toString('base64')
      crypto.pbkdf2(password, user.salt, 10000, 512, (err, dk) =>
        if err?
          callback({code: 400, body: "Got error trying to hash the provided password"})
          return
        else
          user.hash = dk.toString('base64')
          @_upsert(user, 'VALID_TIME', callback)
      )
    else
      @_upsert(user, 'VALID_TIME', callback)

  login: (username, password, callback) =>
    unless username?
      callback({code: 401, body: "Must provide a username when logging in."})
    unless password?
      callback({code: 401, body: "Must provide a password when logging in."})
    query = {_IsTemporalizeUser: true, username}
    config = {query, asOf: 'LATEST'}

    @_query(config, (err, result) =>
      documents = result?.all
      if err?
        @_debug("Got error during login fetching user", err)
        callback(err)
      else if documents.length > 1
        callback({code: 400, body: "Found more than one user with username: #{username}"})
      else if documents.length < 1
        callback({code: 401, body: "Couldn't find user with username: #{username}"})
      else if documents?
        user = documents[0]
        crypto.pbkdf2(password, user.salt, 10000, 512, (err, dk) =>
          if err?
            callback({code: 400, body: "Got error trying to hash the provided password"})
            return
          else
            calculatedHash = dk.toString('base64')
            if user.hash is calculatedHash
              # Create session
              session = {}
              session.id = crypto.randomBytes(24).toString('base64')
              session._IsSession = true
              session._Created = new Date().toISOString()
              delete user.hash
              delete user.salt
              delete user._PreviousValues.hash
              delete user._PreviousValues.salt
              session.user = user
              # TODO: Write the session. By the time we do this to-do, hopefully DocumentDB will have TTL support. Until then, I doubt it'll be an issue.
              @sessionCacheByID[session.id] = session
              @sessionCacheByUsername[user.username] = session
              callback(null, session)
            else
              callback({code: 401, body: "Password does not match"})
        )
      else
        callback({code: 400, body: "Unexpected error during login"})
    )

  logout: (sessionID, callback) =>
    # TODO: Upgrade this to work across servos by deleting sessions stored in database. Need to figure out how to delete the session cache on other servos.
    session = @sessionCacheByID[sessionID]
    if session?
      delete @sessionCacheByID[sessionID]
      delete @sessionCacheByUsername[session.user.username]
    callback(null, true)  # Send back true even if session not found because they are already logged out.

  _getSession: (sessionID, callback) =>
    # TODO: Upgrade this to work across servos by pulling from sessions stored in database if not found in cache. Don't worry about purging the cache for other servos because that will happen next time purgeSessionCache() runs on that servo.
    session = @sessionCacheByID[sessionID]
    if session?
      sessionTTL = session.user.sessionTTL or @sessionTTL
      if new Date() - new Date(session._Created) < sessionTTL
        callback(null, session)
        return session
      else
        delete @sessionCacheByID[sessionID]
        delete @sessionCacheByUsername[session.user.username]
        callback({code: 401, body: "Session expired"})
        return
    else
      callback({code: 401, body: "Session not found"})
      return

  _getTransactionHandler: (transaction) ->
    f = (err, response, header) ->
      unless transaction.err?
        if err?
          # TODO: A-2 - Roll back transaction. Don't forget to remove _UpdateTransactionID and reset _ValidTo of old versions
          transaction.err = err
          transaction.callback(err)
        else
          transaction.responseCount++
          unless transaction.response?
            transaction.response = []
          transaction.response.push(response)
          unless transaction.headers?
            transaction.headers = []
          transaction.headers.push(header)
          if transaction.requestCount > transaction.responseCount
            # Nothing
          else
            se = transaction.se
            se.storageEngineConfig.lastValidFrom = transaction.transactionTimeString
            if transaction.response.length is 1
              transaction.response = transaction.response[0]
            se._writeConfig((err) ->
              transaction.callback(err, transaction.response, transaction.headers)
            )
    return f

  query: (sessionID, config, callback) ->  # POST /query  Maybe later support GET and url parameters
    ###
    sessionID

    [topLevelPartitionKey]

    [secondLevelPartitionKey] You must provide either a topLevelPartitionKey and a secondLevelPartitionKey or a query or all three.  When a
    secondLevelPartitionKey is provided, the query defaults to {@secondLevelPartitionField: secondLevelPartitionKey}
    which will return the entire history of this one entity. If a query and a secondLevelPartitionKey is provided, the
    query is modified with {$and: [{@secondLevelPartitionField: secondLevelPartitionKey}, <oldQuery>]}.

    [query] Required unless a secondLevelPartitionKey is provided. MongoDB-like format.

    [fields] If no fields are specified, all are included.

    [maxItemCount] default: -1. To limit a query to a certain number of documents, provide a limit value. The response will
    include a continuation token that you can pass in to get the next page. Alternatively, you can do paging with a
    query clause on _ValidFrom but be careful to remove the last few documents of each page with the same _ValidFrom
    and use the prior _ValidFrom in the query clause for your next page. We may support this mode of paging
    automatically in the future.

    [continuationTokens] (not implemented) This is an object. The key is the partitionLink. The value is the continuation token for that partition.

    [includeDeleted] (not implemented) default: false. Unless includeDeleted == true, {_Deleted: {$exists: false}} is added to the $and clause.

    [asOf] When a asOf parameter is provided, the query will be done for that moment
      in time. ISO-8601 time formats are supported even partial ones like '2015-01' which specifies midnight GMT on
      January 1, 2015. Specifying asOf = 'LATEST' or 'latest' or 'LAST' or 'last' will use the lastValidTo value. Unless a asOf is
      specified, the query is modified with {$and: [<oldQuery>, {_ValidFrom: {$lte: lastValidFrom}]} to prevent
      partially completed transactions from being returned. When the global @temporalPolicy is set to 'NONE', the
      default asOf is 'LATEST'.
    ###

    # TODO: Upgrade to call _getSession and _query in parallel
    @_getSession(sessionID, (err, session) =>
      if err?
        callback(err)
      else
        @_query(config, (err, result) =>
          if err?
            callback(err)
          authorizedForAll = true
          unauthorizedTenantIDs = []
          for row in result.all
            unless row[@topLevelPartitionField]?
              callback({code: 400, body: "Found documents without #{@topLevelPartitionField} field. Database corruption has likely occured"})
            unless row[@topLevelPartitionField] in session.user.tenantIDsICanRead
              unauthorizedTenantIDs.push(row[@topLevelPartitionField])
              authorizedForAll = false
          if authorizedForAll
            callback(err, result)
          else
            callback({code: 401, body: "Unauthorized for TenantIDs indicated in unauthorizedTenantIDs", unauthorizedTenantIDs})
        )
    )

  _query: (config, callback) ->
    if @storageEngineConfig.mode is 'STOPPED'
      msg = "Storage engine is currently stopped"
      callback(msg)
      return msg

    if config.query? and not _.isPlainObject(config.query)
      callback({code: 400, body: "config.query must be a plain object when calling query()."})
      return

    unless config.query? or (config.secondLevelPartitionKey? and config.topLevelPartitionKey?)
      callback({code: 400, body: "Must provide config.query or (config.topLevelPartitionKey and config.secondLevelPartitionKey) when calling query()."})
      return

    unless config.maxItemCount?
      config.maxItemCount = -1

    if config.query?
      modifiedQuery = JSON.parse(JSON.stringify(config.query))
    else
      modifiedQuery = {}

    if config.fields?
      config.fields = _.union(config.fields, [@topLevelPartitionField])

    if config.secondLevelPartitionKey?
      modifiedQuery[@secondLevelPartitionField] = config.secondLevelPartitionKey

    if config.asOf?
      if config.asOf in ['LATEST', 'LAST', 'latest', 'last']
        config.asOf = @storageEngineConfig.lastValidFrom
      modifiedQuery._ValidTo = {$gt: config.asOf}
      modifiedQuery._ValidFrom = {$lte: config.asOf}
    else
      modifiedQuery._ValidFrom = {$lte: @storageEngineConfig.lastValidFrom}

    querySpec = {query: modifiedQuery, fields: config.fields}

    queryOptions = {maxItemCount: config.maxItemCount}

    partitionList = @_resolveToListOfPartitions(config.topLevelPartitionKey, config.secondLevelPartitionKey)
    @client.queryDocumentsArrayMulti(partitionList, querySpec, queryOptions, callback)
    return

  undelete: () ->
