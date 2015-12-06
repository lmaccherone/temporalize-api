DocumentDBMock = require('documentdb-mock')
path = require('path')

exports.getSnapshotTest =

  storedProcTest: (test) ->
    mock = new DocumentDBMock(path.join(__dirname, '..', 'sprocs', 'get-snapshot'))

    snapshots = [
      {a: 1},
      {b: 2},
      {c: 3}
    ]

    mock.nextResources = snapshots

    mock.package({query: {query: {_OrgId: '1234'}}})

    test.equal(mock.lastBody.count, 3)
    test.ok(!mock.lastBody.continuation?)
    test.deepEqual(mock.lastBody.snapshots, snapshots)

    test.done()