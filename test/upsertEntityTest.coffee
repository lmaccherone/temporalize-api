DocumentDBMock = require('documentdb-mock')
path = require('path')
documentdb = require('documentdb')
utils = require(path.join(__dirname, '..', 'src', 'utils'))

exports.upsertEntityTest =

  basicTest: (test) ->
    mock = new DocumentDBMock(path.join(__dirname, '..', 'mixins', 'upsertEntity'))

    user =
      _EntityID: documentdb.Base.generateGuidId()
      "username": "admin@somewhere.com"
      "salt": "abcd"
      "hashedCredentials": "gNTkDcV8EwZSB0QPdMq/px+bDGARLr30K0mepnWkyZEJOGh2qdtwKw2W4H4csRX603G1zhZ57BGhOfSGGTYFXQ=="
      "orgIDsThisUserCanRead": ["ID1", "ID2", "ID3"]
      "orgIDsThisUserCanWrite": ["ID1", "ID2"]
      "orgIDsThisUserIsAdmin": ["ID1"]

    userCleaned = utils.clone(user)
    delete userCleaned.hashedCredentials
    delete userCleaned.salt

    entityTypes = ["Story"]
    newRevisionOfEntity =
      a: 10
    authorization =
      scheme: 'Basic'
      credentials: 'something'
      basic:
        username: 'admin@somewhere.com'
        password: 'admin'
    authorizationFunction = (userMakingRequest, orgID) ->
      console.log(userMakingRequest, orgID)
      return true

    test.throws(() ->
      mock.nextResources = [utils.clone(user)]
      mock.package(newRevisionOfEntity, authorization, authorizationFunction)
    )

    test.throws(() ->
      cloneUser = utils.clone(user)
      clonedUser.hashedCredentials = '1234'
      mock.nextResources = [clonedUser]
      mock.package(newRevisionOfEntity, authorization, authorizationFunction)
    )

    newRevisionOfEntity._OrgID = 'ID1'
    mock.nextResources = [utils.clone(user)]
    result = mock.package(newRevisionOfEntity, authorization, authorizationFunction)  # Since this is a mixin, it has more than just a single memo parameter
    test.deepEqual(mock.lastBody.user, userCleaned)

    test.done()