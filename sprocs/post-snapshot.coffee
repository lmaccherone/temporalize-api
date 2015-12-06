# !TODO: Need to confirm that this user has write permission for the orgId specified
# If the user passes in fully formed snapshots and the parameter "loadHistory=true"
module.exports = (memo) ->

  # Check input and initialize
  unless memo.body.snapshots?
    throw new Error('post-snapshot must be called with an object containing a `body.snapshots` field.')
  unless memo.body.orgID?
    throw new Error('post-snapshot must be called with an object containing a `body.orgID` field.')
  unless memo.totalCount?
    memo.totalCount = 0
  memo.countForThisRun = 0

  for row in memo.body.snapshots
    row._OrgID = memo.body.orgID
    row._IsSnapshot = true

  collection = getContext().getCollection()
  collectionLink = collection.getSelfLink()
  memo.stillQueueing = true

  writeSnapshot = () ->
    if memo.body.snapshots.length > 0 and memo.stillQueueing
      doc = memo.body.snapshots.pop()
      getContext().getResponse().setBody(memo)
      memo.stillQueueing = collection.createDocument(collectionLink, doc, (error, resource, options) ->
        if error?
          throw new Error(error)
        else if memo.stillQueueing
          memo.countForThisRun++
          memo.totalCount++
          writeSnapshot()
        else
          memo.body.snapshots.push(doc)
          memo.continuation = "value does not matter"
          getContext().getResponse().setBody(memo)
      )
    else
      memo.continuation = null
      getContext().getResponse().setBody(memo)

  writeSnapshot()
