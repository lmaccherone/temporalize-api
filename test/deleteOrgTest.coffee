DocumentDBMock = require('documentdb-mock')
path = require('path')

exports.deleteOrgTest =

  storedProcTest: (test) ->
    mock = new DocumentDBMock(path.join(__dirname, '..', 'sprocs', 'del-org'))

    snapshots = [
      {a: 1},
      {b: 2},
      {c: 3}
    ]

    mock.nextResources = snapshots

    mock.package({params: {link: '1234'}})

    test.equal(mock.lastBody.rowsDeleted, 3)
    test.ok(!mock.lastBody.continuation?)

    test.done()