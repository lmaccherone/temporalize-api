DocumentDBMock = require('documentdb-mock')
path = require('path')

exports.postUserTest =

  storedProcTest: (test) ->
#    mock = new DocumentDBMock(path.join(__dirname, '..', 'sprocs', 'post-entity'))
#
#    authorization =
#      scheme: 'Basic'
#      credentials: 'some funky string'
#      basic:
#        username: 'admin'
#        password: 'admin-password'
#
#    user =
#      username: 'john@somewhere.com'
#      entityID: '1234'
#      salt: 'abcd'
#      hashedCredentials: 'something'
#      orgLinks: ['link1', 'link2']
#
#    mock.package({body: user, authorization})

#    test.equal(mock.lastBody.body.name, user.name)
#    test.equal(mock.rows.length, 1)
#    row = mock.rows[0]
#    test.deepEqual(row, user)
#    test.equal(row._ValidTo, "9999-01-01T00:00:00.000Z")

    test.done()