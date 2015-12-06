# !TODO: Need to confirm that this user has write permission for the orgId that they specified.
module.exports = (memo) ->

  # Check input and initialize
  unless memo.body.name?
    throw new Error('postOrg must be called with an object containing a `name` field.')
  unless memo.body.uniqueIDField?
    throw new Error('post-org must be called with an object containing a `uniqueIDField` field.')
  memo.stillQueueing = true

  now = new Date().toISOString()
  newOrg = memo.body
  orgLink = newOrg._self or memo.params?.link
  if orgLink?

    # read existing org and consider this an update
  else
    # Add _ValidFrom and _ValidTo fields
    newOrg._ValidFrom = now
    newOrg._ValidTo = "9999-01-01T00:00:00.000Z"
    newOrg.lastValidTo = now
    newOrg._IsOrg = true

  collection = getContext().getCollection()
  collectionLink = collection.getSelfLink()

  memo.stillQueueing = collection.createDocument(collectionLink, newOrg, (error, resource, options) ->
    if error?
      throw new Error(error)

    if memo.stillQueueing
      memo.continuation = null
      memo.resource = resource
    else
      memo.continuation = 'value does not matter'
    getContext().getResponse().setBody(memo)
  )
