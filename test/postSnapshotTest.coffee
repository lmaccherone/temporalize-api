DocumentDBMock = require('documentdb-mock')
path = require('path')

exports.postSnapshotTest =

  storedProcTest: (test) ->
    mock = new DocumentDBMock(path.join(__dirname, '..', 'sprocs', 'post-snapshot'))

    snapshots = [
      {a: 1},
      {b: 2},
      {c: 3}
    ]

    reverse = []
    for row in snapshots
      reverse.unshift(row)

    mock.package({body: {snapshots: snapshots, orgID: '1234'}})

    test.equal(mock.lastBody.totalCount, 3)
    test.equal(mock.lastBody.countForThisRun, 3)
    test.ok(!mock.lastBody.continuation?)
    test.deepEqual(mock.rows, reverse)

    test.done()