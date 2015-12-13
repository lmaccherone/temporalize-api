path = require('path')
{} = require('documentdb-utils')
{ServerSideMock} = require('documentdb-mock')

mock = new ServerSideMock(path.join(__dirname, '..', 'sprocs', 'simulateKanban'))

module.exports =

  theTest: (test) ->

    entitiesDesired = 1
    startDate = "2015-11-13"
    mock.package({startDate, entitiesDesired})

    memo = mock.lastBody
    console.log(memo)
#    test.deepEqual(memo, {remaining: 0, totalCount: 3, countForThisRun: 3, stillQueueing: true, continuation: null})
#    test.equal(mock.rows.length, entitiesDesired)
    for key in ['ProjectHierarchy', 'Priority', 'Severity', 'Points', 'State']
      test.ok(mock.lastRow.hasOwnProperty(key))

    test.done()