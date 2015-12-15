{_} = require('documentdb-utils')

module.exports =
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
    @_debug("Sending query: #{JSON.stringify(querySpec)}")

    queryOptions = {maxItemCount: config.maxItemCount}

    partitionList = @_resolveToListOfPartitions(config.topLevelPartitionKey, config.secondLevelPartitionKey)
    @client.queryDocumentsArrayMulti(partitionList, querySpec, queryOptions, callback)
    return