# TODO: If upsert is missing a _TenantID and the user is not _IsTemporalizeSuperUser, then use the user's _TenantID
# TODO: If upsert is missing _EntityID, then generate one.

# TODO: A-2 Disallow changing _TenantID and _EntityID on upsert

HashRing = require('hashring')
crypto = require('crypto')
zxcvbn = require('zxcvbn')
path = require('path')
lumenize = require('lumenize')
{WrappedClient, getLink, getLinkArray, getDocLink, _, async, getGUID, loadSprocs} = require('documentdb-utils')

#seQuery = require(path.join(__dirname, 'query'))
#superUserOnly = require(path.join(__dirname, 'superUserOnly'))

module.exports = class StorageEngine
  ###


  
  ###

  constructor: (userConfig, autoInitialize = true, callback) ->
    ###

    ###
    unless callback?
      callback = autoInitialize
      autoInitialize = true
    unless userConfig?
      userConfig = {}
    config = _.cloneDeep(userConfig)

    # Check the environment
    @environment = process.env.NODE_ENV
    unless @environment? and @environment in ['development', 'testing', 'production']
      callback({code: 400, body: "environment variable NODE_ENV must be set to development, testing, or production"})

    # Set defaults
    @topLevelPartitionField = config.topLevelPartitionField or '_TenantID'
    @secondLevelPartitionField = config.secondLevelPartitionField or '_EntityID'
    if @environment is 'production'
      @firstTopLevelID = config.firstTopLevelID or 'A'
    else
      @firstTopLevelID = config.firstTopLevelID or @environment + '-A'
    @firstSecondLevelID = config.firstSecondLevelID or '1'
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
    @pauseConfigReading = false

    @lastMessage = ''
    @sameMessageCount = 1

    @HIGHEST_DATE_STRING = '9999-01-01T00:00:00.000Z'
    @LOWEST_DATE_STRING = '0001-01-01T00:00:00.000Z'
    @SYSTEM_FIELDS = ["id", "_ValidFrom", "_ValidTo", "_EntityID", "_TenantID", "_CreationTransactionID", "_UpdateTransactionID", "_PreviousValues"]

    @readConfigRetries = 0
#    @lastTimeConfigWasRead = new Date()

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

    if autoInitialize
      @_initialize(config, callback)
    else
      callback(null, this)

    return this

  _initialize: (config, callback) ->
    unless callback?
      callback = config
      config = {}
    # Get client
    if config.wrappedClient?
      @client = wrappedClient
    else
      if config.client?
        @_client = config.client
        new WrappedClient(@_client)
      else
        @client = new WrappedClient(null, null, null, 'Session')  # TODO: Change to session consistency

    # Unless it already exists, create first database
    @_debug("Checking existence or creating database: #{@firstTopLevelID}")
    @client.createDatabase({id: @firstTopLevelID}, (err, response) =>
      if err? and err.code isnt 409
        throw new Error(JSON.stringify(err))
      else
        if err?.code is 409
          @_debug("Database already existed")
        else
          @_debug("Created Database", response)

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
            @_debug("Created Collection", response)
            collectionIDLink = getLink(@firstTopLevelID, @firstSecondLevelID)
            if response?
              @linkCache[collectionIDLink] = response._self
            @_readOrCreateInitialConfig((err, response, headers) =>
              username = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
              password = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
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

  _delay = (ms, func) ->
    setTimeout(func, ms)

  _debug: (message, content, content2) ->
    # TODO: Add logging here. Current favorite is https://github.com/trentm/node-bunyan to Loggly
    if @debug or process.env.NODE_ENV isnt 'production'
      if message is @lastMessage
        @sameMessageCount++
        process.stdout.write('\r')
      else
        @sameMessageCount = 1
        process.stdout.write('\n')
      process.stdout.write("#{new Date().toISOString()} #{message} (#{@sameMessageCount})")
      @lastMessage = message
    if @debug
      @sameMessage = ''
      @sameMessageCount = 1
      if content?
        console.log('\n', JSON.stringify(content, null, 2))
      if content2?
        console.log('\n', JSON.stringify(content2, null, 2))

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
        @readConfigRetries = 0
        if @pauseConfigReading
          @_debug('Config not retrieved because @pauseConfigReading was set')
        else
          @storageEngineConfig = response
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

  _writeConfig: (callback) =>
    @pauseConfigReading = true
    @client.upsertDocument(getLink(@firstTopLevelID, @firstSecondLevelID), @storageEngineConfig, (err, response, header) =>
      @pauseConfigReading = false
      if err?
        callback(err)
        return
      else
        @_debug('Successfully wrote @storageEngineConfig to database', response, header)
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

  upsertTenant: (sessionID, tenant, callback) =>  # GET /upsert-tenant
    # Since Temporalize owns this entity type, the temporalPolicy is always 'VALID_TIME'
    if sessionID?
      @_getSession(sessionID, (err, session) =>
        if session.user._IsTemporalizeSuperUser or tenant[@topLevelPartitionField] in session.user.tenantIDsICanAdmin
          @_upsertTenant(tenant, callback)
        else
          callback({
            code: 401,
            body: "User with username: #{session.user.username} does not have permission to administer tenant with id: #{tenant[@topLevelPartitionField]}"
          })
          return
      )
    else
      callback({code: 401, body: "Missing sessionID"})

  _upsertTenant: (tenant, callback) =>
    unless tenant.name? and tenant.name.length > 0
      callback({code: 400, body: "Missing name"})
    unless tenant._TenantID? and tenant._EntityID? and tenant._TenantID is tenant._EntityID
      callback({code: 400, body: "_TenantID and _EntityID are either missing or don't match"})
    tenant._IsTemporalizeTenant = true
    # TODO: check to see if the new name is already in use and error if it is
    @_upsert(tenant, 'VALID_TIME', callback)

  createTenant: (tenant, adminUser, callback) =>
    ###
    This is a higher level operation that has more checking and automation than upsertTenant. In particular, you must
    pass in the first admin user for the tenant. Neither the tenant nor the user can exist before calling.
    Also, the user does not need to be logged in (thus no sessionID).
    It's intended to be used in a sign up process, where the user attempting to sign up is not logged in.
    ###

    @_debug("Creating new tenant for #{tenant.name} #{adminUser.username}")
    unless tenant?.name?
      callback({code: 400, body: "Must provide a tenant.name when creating a tenant"})
    if tenant?._EntityID?
      callback({code: 400, body: "Must not provide tenant._EntityID when creating a tenant"})
    if tenant?._TenantID?
      callback({code: 400, body: "Must not provide tenant._TenantID when creating a tenant"})

    unless adminUser?.username?
      callback({code: 400, body: "Must provide adminUser.username when creating a tenant"})
    unless adminUser?.password?
      callback({code: 400, body: "Must provide adminUser.password when creating a tenant"})
    if adminUser?._EntityID?
      callback({code: 400, body: "Must not provide adminUser._EntityID when creating a tenant"})
    if adminUser?._TenantID?
      callback({code: 400, body: "Must not provide adminUser._TenantID when creating a tenant"})

    # confirm that tenant.name and adminUser.username are not already in use
    tenantQuery = {name: tenant.name}
    userQuery = {username: adminUser.username}

    async.parallel({
      tenantResult: (callback) =>
        @_query({query: tenantQuery}, callback)
      userResult: (callback) =>
        @_query({query: userQuery}, callback)
    }, (err, results) =>  # results is now equals to: {tenantResult: ..., userResult: ...}
      if err?
        callback(err)
      else
        unless results.tenantResult.all.length is 0
          callback({code: 400, body: "Tenant #{tenant.name} already exists"})
          return
        unless results.userResult.all.length is 0
          callback({code: 400, body: "User #{adminUser.username} already exists"})
          return

        # build list of upserts
        tenantGUID = getGUID()
        userGUID = getGUID()
        tenant._EntityID = tenantGUID
        tenant._TenantID = tenantGUID
        adminUser._EntityID = userGUID
        adminUser._TenantID = tenantGUID
        adminUser.tenantIDsICanAdmin = [tenantGUID]
        async.parallel({
          tenant: (callback) =>
            @_upsertTenant(tenant, callback)
          adminUser: (callback) =>
            @_upsertUser(adminUser, callback)
        }, (err, results) =>
          if err?
            # TODO: A-2 Roll back
            callback(err)
            return
          tenant = results.tenant[0]
          adminUser = results.adminUser
          response = {tenant, adminUser}
          callback(null, response)
        )
    )


  upsertUser: (sessionID, user, password, callback) =>  # GET /upsert-user
    # You can either provide the password as a field inside the user entity or as a seperate parameter
    # Since Temporalize owns this entity type, the temporalPolicy is always 'VALID_TIME'
    @_debug("Upserting user with username: #{user.username}")
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
      callback({code: 401, body: "Missing sessionID"})

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
    user.username = user.username.toLowerCase().trim()
    user.tenantIDsICanWrite = _.union(user.tenantIDsICanWrite, user.tenantIDsICanAdmin)
    user.tenantIDsICanRead = _.union(user.tenantIDsICanRead, user.tenantIDsICanWrite)
    if password?
      user.salt = crypto.randomBytes(128).toString('base64')
      crypto.pbkdf2(password, user.salt, 10000, 512, (err, dk) =>
        if err?
          callback({code: 400, body: "Got error trying to hash the provided password"})
          return
        else
          user.hash = dk.toString('base64')
#          @_upsert(user, 'VALID_TIME', callback)
          @_upsert(user, 'VALID_TIME', @_getUpsertUserUpsertCallback(callback))
      )
    else
#      @_upsert(user, 'VALID_TIME', callback)
      @_upsert(user, 'VALID_TIME', @_getUpsertUserUpsertCallback(callback))

  _getUpsertUserUpsertCallback: (callback) ->
    f = (err, response) ->
      user = response
      delete user.hash
      delete user.salt
      delete user._PreviousValues.hash
      delete user._PreviousValues.salt
      callback(err, user)
    return f

  login: (username, password, callback) =>
    @_debug("Attempting login for user with username: #{username}")
    username = username.toLowerCase().trim()
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
        callback({code: err.code, body: err.body})
        return
      else if documents.length > 1
        callback({code: 400, body: "Found more than one user with username: #{username}. Database corruption is likely"})
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
              callback({code: 401, body: "Incorrect password"})
        )
      else
        callback({code: 400, body: "Unexpected error during login"})
    )

  logout: (sessionID, callback) =>
    # TODO: Upgrade this to work across servos by deleting sessions stored in database. Need to figure out how to delete the session cache on other servos.
    @_debug("Attempting logout for sessionID: #{sessionID}")
    if sessionID?
      session = @sessionCacheByID[sessionID]
      if session?
        delete @sessionCacheByID[sessionID]
        delete @sessionCacheByUsername[session.user.username]
      @_debug("Logout successful for user with username: #{session.user.username}")
      callback(null, true)  # Send back true even if session not found because they are already logged out.
    else
      callback({code: 400, body: "SessionID required on call to logout"})

  _getSession: (sessionID, callback) =>
    # TODO: Upgrade this to work across servos by pulling from sessions stored in database if not found in cache. Don't worry about purging the cache for other servos because that will happen next time purgeSessionCache() runs on that servo.
    session = @sessionCacheByID[sessionID]
    if session?
      sessionTTL = session.user.sessionTTL or @sessionTTL
      if new Date() - new Date(session._Created) < sessionTTL
        callback(null, session)
        return session
      else
        @logout(sessionID, (err, response) ->
          if not err? and response
            callback({code: 401, body: "Session expired"})
          else
            callback({code: 400, body: "Error logging out expired session"})  # I'm pretty sure, it's impossible to see this but it's here just in case
        )
    else
      callback({code: 401, body: "Session not found"})
      return

  _getTransactionHandler: (transaction) ->
    f = (err, response, header) ->
      unless transaction.err?
        if err?
          # TODO: A-2 - Roll back transaction. Don't forget to remove _UpdateTransactionID and reset _ValidTo of old versions
          console.error("*** DATABASE IS NOW CORRUPT DUE TO LACK OF ROLL BACK ***")
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
              if err?
                f({code: 400, body: "Error writing config at end of transaction handler"})
              else
                # TODO: On second upsert, the below only returns the first version. Should probably not return anything but _EntityIDs
                transaction.callback(err, transaction.response, transaction.headers)
            )
    return f

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
    unless callback?
      callback = temporalPolicy
      temporalPolicy = null
    unless temporalPolicy?
      temporalPolicy = @temporalPolicy
    if @terminate
      callback({code: 400, body: 'Cannot call _upsert when @terminate is true'})
    else
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
      transactionHandler({code: 400, body: "Every row in upsert must have a #{@topLevelPartitionField} field"})
      return
    unless upsert[@secondLevelPartitionField]?
      transactionHandler({code: 400, body: "Every row in upsert must have a #{@secondLevelPartitionField} field"})
      return
    if upsert[@secondLevelPartitionField] in transaction.entityIDsForThisTransaction
      transactionHandler({code: 400, body: "_EntityID: #{@secondLevelPartitionField} is duplicated in upsert list"})
      return
    else
      transaction.entityIDsForThisTransaction.push(upsert[@secondLevelPartitionField])

    upsert._CreationTransactionID = transaction.id
    upsert._ValidFrom = transaction.transactionTimeString
    upsert._ValidTo = @HIGHEST_DATE_STRING

    query = {_ValidTo: @HIGHEST_DATE_STRING}
    query[@secondLevelPartitionField] = upsert[@secondLevelPartitionField]
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
          newVersion = _.cloneDeep(oldVersion)
          delete newVersion.id
          newVersion._PreviousValues = {}
          nothingChanged = true
          for key, value of upsert
            if upsert[key]?  # This is intentionally not value? because value might be null. The upsertTest confirms this works as expected
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
          upsertCopy = _.cloneDeep(upsert)
          upsertCopy._PreviousValues = {}
          for key, value of upsertCopy
            unless key in @SYSTEM_FIELDS
              if value?
                upsertCopy._PreviousValues[key] = null
          transaction.requestCount++
          @client.createDocument(collectionLink, upsertCopy, transactionHandler)
    )

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
          newAll = []
          for row in result.all
            unless row[@topLevelPartitionField]?
              callback({code: 400, body: "Found documents without #{@topLevelPartitionField} field. Database corruption has likely occured"})
            if session.user._IsTemporalizeSuperUser or row[@topLevelPartitionField] in session.user.tenantIDsICanRead
              if row._IsTemporalizeUser
                delete row.hash
                delete row.salt
              newAll.push(row)
            else
              unauthorizedTenantIDs.push(row[@topLevelPartitionField])
              authorizedForAll = false
          if authorizedForAll
            callback(err, {stats: result.stats, all: newAll})
          else
            callback({code: 401, body: "Unauthorized for TenantIDs indicated in unauthorizedTenantIDs", unauthorizedTenantIDs})
        )
    )

  _query: (config, callback) ->
    if @storageEngineConfig.mode is 'STOPPED'
      msg = "Storage engine is currently stopped"
      callback(msg)  # TODO: Upgrade to code/body
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
      modifiedQuery = _.cloneDeep(config.query)
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
    partitionList = @_resolveToListOfPartitions(config.topLevelPartitionKey, config.secondLevelPartitionKey)
    queryOptions = {maxItemCount: config.maxItemCount}
    @_debug("Sending query: #{JSON.stringify(querySpec)} to #{JSON.stringify(partitionList)} with options: #{JSON.stringify(queryOptions)}")

    @client.queryDocumentsArrayMulti(partitionList, querySpec, queryOptions, callback)
    return

  initializePartition: (username, password, callback) =>
    if process.env.NODE_ENV is 'production'
      return callback("initializePartition is not supported in production")
    sysUsername = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
    sysPassword = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
    if username is sysUsername and password is sysPassword
      @terminate = false  # TODO: This is a potential race condition. It could attempt an operation before the database is ready. Consider moving @terminate=false into _initialize, but make sure that we fix the tests that set @terminate=true at the beginngin of execution, if there are any.
      @_initialize((err, result) =>
        if err?
          callback(err)
        else
          callback(null, result)
      )
    else
      callback({code: 401, body: "Invalid login for initializeTestPartition"})

  deletePartition: (username, password, callback) =>
    if process.env.NODE_ENV is 'production'
      return callback("deletePartition is not supported in production")
    @terminate = true
    sysUsername = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
    sysPassword = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
    if username is sysUsername and password is sysPassword
      @client.deleteDatabase(getLink(@firstTopLevelID), (err, result) =>
        if err? and err.code isnt 404
          callback(err)
        else
          callback(null, result)
      )
    else
      callback({code: 401, body: "Invalid login for deletePartition"})

  loadSprocs: (scriptsDirectory, callback) =>  # TODO: Get rid of this and automatically do it in _initialize. Change timeInStateTest and delete from loadEndpoints, and remove call in server.coffee
    # TODO: Should be restricted to super user
    collectionLinks = @_resolveToListOfPartitions()
    client = @client
    config = {scriptsDirectory, client, collectionLinks}
    return loadSprocs(config, callback)

  executeSproc: (sprocName, memo, callback) =>
    @_debug("Executing sproc #{sprocName} on all paritions")
    # TODO: Should be restricted to super user
    collectionLinks = @_resolveToListOfPartitions()
    sprocLinks = getLinkArray(collectionLinks, sprocName)
    @_debug("Executing sproc #{sprocName} with these links: #{sprocLinks}")
    @client.executeStoredProcedureMulti(sprocLinks, memo, callback)

  undelete: () ->
    # Do nothing

  timeInState: (sessionID, config, callback) =>
    # TODO: Allow for permissions to see aggregations that might be looser than read (take union of TenantIDsICanRead and TenantIDsICanAggregate)
    modifiedQuery = {$and: [config.query, config.stateFilter]}  # TODO: Add a function to documentdb-utils to merge two filters
    queryConfig = {query: modifiedQuery}
    @query(sessionID, queryConfig, (err, result) ->
      if err?
        return callback({code: err.code, body: err.body})
      calculator = new lumenize.TimeInStateCalculator(config)
      today = new Date()
      startOn = new Date(today.valueOf() - 30*1000*60*60*24).toISOString()
      endBefore = today.toISOString()
      calculator.addSnapshots(result.all, startOn, endBefore)

      callback(null, calculator.getResults())
    )
    
  timeSeries: (sessionID, config, callback) =>
    # TODO: Allow for permissions to see aggregations that might be looser than read (take union of TenantIDsICanRead and TenantIDsICanAggregate)
    unless config.query?
      config.query = {}
    @query(sessionID, {query: config.query}, (err, result) ->
      if err?
        return callback({code: err.code, body: err.body})
      calculator = new lumenize.TimeSeriesCalculator(config)
      today = new Date()
      startOn = new Date(today.valueOf() - 30*1000*60*60*24).toISOString()
      endBefore = today.toISOString()
#      sortedResults = _.sortBy(result.all, '_ValidFrom')  # TODO: This sorting should really be done inside of Lumenize
      sortedResults = result.all
      calculator.addSnapshots(sortedResults, startOn, endBefore)

      callback(null, calculator.getResults())
    )