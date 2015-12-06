# !TODO: Need to confirm that this user has write permission for the orgId that they specified.
module.exports = (memo) ->
  sqlFromMongo = require('sql-from-mongo')

  collection = getContext().getCollection()

  unless memo?.params?.link?
    throw new Error('Must pass in memo.params.link to del-org stored procedure.')
  unless memo.rowsDeleted?
    memo.rowsDeleted = 0
  unless memo.continuation?
    memo.continuation = null

  toDelete = []

  mongoQueryObject = {"_OrgID": memo.params.link}
  queryString = 'SELECT c._self, c._etag FROM c WHERE ' + sqlFromMongo.sqlFromMongo(mongoQueryObject, 'c')

  memo.stillQueueing = true

  queryOnePage = () ->
    if memo.stillQueueing
      responseOptions =
        continuation: memo.continuation
        pageSize: 1000
      setBody()
      memo.stillQueueing = collection.queryDocuments(collection.getSelfLink(), queryString, responseOptions, onReadDocuments)

  onReadDocuments = (err, resources, options) ->
    if err
      throw err

    if options.continuation?
      memo.continuation = options.continuation
    else
      memo.continuation = null

    toDelete = resources
    deleteOneDoc()

  deleteOneDoc = () ->
    if memo.stillQueueing and toDelete.length > 0
      oldDocument = toDelete.pop()
      documentLink = oldDocument._self
      etag = oldDocument._etag
      options = {etag}  # Sending the etag per best practice, but not handling it if there is conflict.
      getContext().getResponse().setBody(memo)
      memo.stillQueueing = collection.deleteDocument(documentLink, options, (err, resources, options) ->
        if err
          throw err

        memo.rowsDeleted++
        deleteOneDoc()
      )
    else if memo.stillQueuing and memo.continuation?
      queryOnePage()

  setBody = () ->
    getContext().getResponse().setBody(memo)

  queryOnePage()
  return memo
