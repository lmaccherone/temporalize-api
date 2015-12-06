# This function will be mixed into sprocs for creating/updating orgs and users, as well as a generic post-entity sproc
# The basic idea is that we don't ever replace or delete old data. We simply add a new snapshot

module.exports = (newRevisionOfEntity, authorization, authorizationFunction) ->

  defaultAuthorizationFunction = (userMakingRequest, orgID) ->
    if orgID in userMakingRequest.orgIDsThisUserCanWrite
      return true
    else
      throw new Error("User does not have permission to update this entity")

  unless memo?
    memo = {}
  unless authorizationFunction?
    authorizationFunction = defaultAuthorizationFunction

  sqlFromMongoPackage = require('sql-from-mongo')
  sqlFromMongo = sqlFromMongoPackage.sqlFromMongo
  pbkdf2 = require('../mixins/pbkdf2')

  collection = getContext().getCollection()

  # fetch the user by username specified in authorization
  fetchUser = (username, next) ->
    queryJSON = {username}
    queryString = 'SELECT * FROM c WHERE ' + sqlFromMongo(queryJSON, 'c')
    responseOptions =
      pageSize: 2
    collection.queryDocuments(collection.getSelfLink(), queryString, responseOptions, next)

  gotUser = (err, resources, options) ->
    if err
      throw new Error(err)
    if resources.length > 1
      throw new Error("Found more than one user with the username: #{username}")
    if resources.length is 0
      throw new Error("Found no user with the username: #{username}")
    user = resources[0]
    memo.user = user

    memo.gotHere = true
    # Confirm that the authorization matches the hash of the retrieved user
    # TODO: calculating the hash with 987 iterations took 500 RUs. An S1 only has 250 RUs so, I reduced it to 32. Upgrade
    # to use tokens. We can store the token in the user document along with the date-timestamp when it expires.
    # We'll have to figure out a way to indicate authentication failure other than throwing an error so the restify API
    # can send back a 403. Alternatively, I could do the authentication in restify instead of DocumentDB sprocs. Note, be
    # sure to send back the token as a cookie (restify-cookies) to support browser access as well as a header to support non-browser calling.
    # The username needs to get in the cookies also, but we can just keep using the basic auth username for non-cookie auth
    hashOfCallerAuth = pbkdf2(password, user.salt, 32, 64)
    memo.hashOfCallerAuth = hashOfCallerAuth
    unless hashOfCallerAuth is user.hashedCredentials
      throw new Error('Authentication failed')

    delete memo.user.password  # Shouldn't be in here but doing this defensively
    delete memo.user.salt
    delete memo.user.hashedCredentials
    delete memo.user._rid
    delete memo.user._ts
    delete memo.user._self
    delete memo.user._attachments
    delete memo.user._etag

    # if the newRevisionOfEntity does not have an _OrgID, then check the orgIDsThisUserCanWrite field of the user. If it's only one long, then add it to the orgID field in the newRevisionOfEntity, else throw an error.
    unless newRevisionOfEntity._OrgID
      if user.orgIDsThisUserCanWrite.length is 1
        newRevisionOfEntity._OrgID = user.orgIDsThisUserCanWrite[0]
      else
        throw new Error('newRevisionOfEntity is missing _OrgID and the user can write to none or more than one org. Provide an _OrgID with newRevisionOfEntity.')


  # hasPermissionResult = hasPermission(user.username, entity._OrgLink)
  # if hasPermissionResult, then
  #   uniqueIDField = "_EntityID"  # Assume this. If it's something else like ObjectID for Rally, then copy ObjectID to _EntityID upon addition. We can add functionality to the post-snapshots sproc by passing in a uniqueIDField config.
  #   if not entity[uniqueIDField]? then,
  #     generate new uniqueID and set entity[uniqueIDField] to it.
  #   else
  #     fetch the latest version of the entity -> lastEntitySnapshot
  #     it's possible that will not return anything, meaning the entity has been deleted. Consider this new post to be restoring it at the current moment in time. In which case, you'll need to do another query to retrieve the most recent version. Note, DO NOT CHANGE THE _ValidTo of this old entity.
  #     walk through the fields of the entity replacing the values of the retrieved entity with the new ones. If there is a field explicitly set to null in the new entity, then delete it from the entity.
  #   set the _ValidFrom and _ValidTo fields
  #   set the _Is<EntityType> field
  #   set the _PreviousValues field
  #   insert the new entity
  #   set the _ValidTo of the old entity to the _ValidFrom of this new one
  #   update the old entity
  #   update the lastValidTo of the org. Use the same old pattern that will increment it by 1 millisecond at the least. We'll have to handle etag conflict for this update.
  # Else (no permission), throw error


  basicAuth = authorization.basic
  username = basicAuth.username
  password = basicAuth.password
  user = null
  fetchUser(username, gotUser)

  getContext().getResponse().setBody(memo)
  return memo
