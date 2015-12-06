# !TODO: Need to confirm that this user has write permission for the orgId that they specified.

module.exports = (memo) ->
  sqlFromMongoPackage = require('sql-from-mongo')
  sqlFromMongo = sqlFromMongoPackage.sqlFromMongo
#  sqlFromMongo = () ->
#    return 'c.junk = 0'

  collection = getContext().getCollection()

  compareValidFromForSorting = (a, b) ->
    if a._ValidFrom < b._ValidFrom
      return -1
    if a._ValidFrom > b._ValidFrom
      return 1
    return 0

  unless memo.continuation?
    memo.continuation = null
  unless memo.query.query?
    throw 'Must provide a query when calling get-snapshot'

  if typeof(memo.query.query) is 'string'
    memo.query.query = JSON.parse(memo.query.query)

  queryString = 'SELECT * FROM c WHERE ' + sqlFromMongo(memo.query.query, 'c')

  memo.stillQueueing = true
  memo.snapshots = []
  memo.count = 0

  setBody = () ->
    getContext().getResponse().setBody(memo)

  memo.sql = queryString
  setBody()

  queryOnePage = () ->
    if memo.stillQueueing
      responseOptions =
        continuation: memo.continuation
        pageSize: 1000
      setBody()
      memo.stillQueueing = collection.queryDocuments(collection.getSelfLink(), queryString, responseOptions, onReadDocuments)

  onReadDocuments = (err, resources, options) ->
    if err
      throw new Error(err)

    # TODO: Need to upgrade documentDBUtils so it that I can pass back one big batch after another and not have them come back in the memo.
    # For now, just going to error if it the sproc times out. Should get me at least 10,000 documents.
    if not memo.stillQueueing and options.continuation
      throw new Error("Query results in too many rows. Provide a more selective query.")

    if options.continuation?
      memo.continuation = options.continuation
    else
      memo.continuation = null
    for row in resources
      delete row._rid
      delete row._ts
      delete row._self
      delete row._attachments
      delete row._etag
    memo.snapshots = memo.snapshots.concat(resources)
    memo.count = memo.snapshots.length

    if memo.stillQueueing and memo.continuation?
      setBody()
      queryOnePage()
    else
      memo.snapshots.sort(compareValidFromForSorting)
      setBody()
      return memo

  queryOnePage()
