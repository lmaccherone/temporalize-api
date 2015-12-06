# !TODO: Need to confirm that this user has write permission for the orgID that they specified.
module.exports = (memo) ->

  upsertEntity = require('../mixins/upsertEntity')

  # Check input and initialize
  unless memo.authorization?  # Check credentials
    throw new Error('post-entity must be called with an object containing a `authorization` field.')
  memo.stillQueueing = true

  now = new Date().toISOString()

  newRevisionOfEntity = memo.body
  authorization = memo.authorization
  getContext().getResponse().setBody(memo)

  upsertEntity(newRevisionOfEntity, authorization)

#  memo.stillQueueing = fetchUser(newOrUpdatedUser, (error, response, options) ->
#    if error?
#      throw new Error(error)

#    if response?  # found a user with that name
      # confirm that it is the same org as this one



#  )


#  userLink = newUser._self or memo.params?.link
#  if userLink?
#
#    # read existing user and consider this an update
#  else
#    # Add _ValidFrom and _ValidTo fields
#    newUser._ValidFrom = now
#    newUser._ValidTo = "9999-01-01T00:00:00.000Z"
#    newUser._IsUser = true

  # TODO: Don't forget to update the Org's lastValidTo

#  collection = getContext().getCollection()
#  collectionLink = collection.getSelfLink()
#
#  memo.stillQueueing = collection.createDocument(collectionLink, newOrg, (error, resource, options) ->
#    if error?
#      throw new Error(error)
#
#    if memo.stillQueueing
#      memo.continuation = null
#      memo.resource = resource
#    else
#      memo.continuation = 'value does not matter'
#    getContext().getResponse().setBody(memo)
#  )
