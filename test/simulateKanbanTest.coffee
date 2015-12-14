path = require('path')
{} = require('documentdb-utils')
{ServerSideMock} = require('documentdb-mock')

mock = new ServerSideMock(path.join(__dirname, '..', 'sprocs', 'simulateKanban'))

module.exports =

  theTest: (test) ->

    entitiesDesired = 100
    startDate = "2015-11-13"
    mock.package({startDate, entitiesDesired})

    memo = mock.lastBody
#    console.log(mock.rows)
    console.log(memo.wip)
    test.ok(5 < memo.wip.Ready <= 10)
    test.ok(3 < memo.wip['In Progress'] <= 5)
    test.ok(3 < memo.wip['Accepted'] <= 10)
    test.ok(memo.wip.Shipped > 7)

    test.done()