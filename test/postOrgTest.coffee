DocumentDBMock = require('documentdb-mock')
path = require('path')

exports.postOrgTest =

  storedProcTest: (test) ->
    mock = new DocumentDBMock(path.join(__dirname, '..', 'sprocs', 'post-org'))

    org =
      name: 'Testing'
      uniqueIDField: 'ObjectID'

    mock.package({body: org})

    test.equal(mock.lastBody.body.name, org.name)
    test.equal(mock.lastBody.body.uniqueIDField, 'ObjectID')
    test.equal(mock.rows.length, 1)
    row = mock.rows[0]
    test.deepEqual(row, org)
    test.equal(row._ValidTo, "9999-01-01T00:00:00.000Z")

    test.done()