restify = require('restify')
lumenize = require('lumenize')
{TimeSeriesCalculator, Time} = lumenize
documentdb = require('documentdb')

snapshotsCSV = [
  ["ObjectID", "_ValidFrom",               "_ValidTo",                 "ScheduleState", "PlanEstimate", "TaskRemainingTotal", "TaskEstimateTotal"],

  [1,          "2010-10-10T15:00:00.000Z", "2011-01-02T13:00:00.000Z", "Ready to pull", 5             , 15                  , 15],

  [1,          "2011-01-02T13:00:00.000Z", "2011-01-02T15:10:00.000Z", "Ready to pull", 5             , 15                  , 15],
  [1,          "2011-01-02T15:10:00.000Z", "2011-01-03T15:00:00.000Z", "In progress"  , 5             , 20                  , 15],
  [2,          "2011-01-02T15:20:00.000Z", "2011-01-03T15:00:00.000Z", "Ready to pull", 3             , 5                   , 5],
  [3,          "2011-01-02T15:30:00.000Z", "2011-01-03T15:00:00.000Z", "Ready to pull", 5             , 12                  , 12],

  [2,          "2011-01-03T15:00:00.000Z", "2011-01-04T15:00:00.000Z", "In progress"  , 3             , 5                   , 5],
  [3,          "2011-01-03T15:10:00.000Z", "2011-01-04T15:00:00.000Z", "Ready to pull", 5             , 12                  , 12],
  [4,          "2011-01-03T15:20:00.000Z", "2011-01-04T15:00:00.000Z", "Ready to pull", 5             , 15                  , 15],
  [1,          "2011-01-03T15:30:00.000Z", "2011-01-04T15:00:00.000Z", "In progress"  , 5             , 12                  , 15],

  [1,          "2011-01-04T15:00:00.000Z", "2011-01-06T15:00:00.000Z", "Accepted"     , 5             , 0                   , 15],
  [2,          "2011-01-04T15:10:00.000Z", "2011-01-06T15:00:00.000Z", "In test"      , 3             , 1                   , 5],
  [3,          "2011-01-04T15:20:00.000Z", "2011-01-05T15:00:00.000Z", "In progress"  , 5             , 10                  , 12],
  [4,          "2011-01-04T15:30:00.000Z", "2011-01-06T15:00:00.000Z", "Ready to pull", 5             , 15                  , 15],
  [5,          "2011-01-04T15:50:00.000Z", "2011-01-06T15:00:00.000Z", "Ready to pull", 2             , 4                   , 4],

  [3,          "2011-01-05T15:00:00.000Z", "2011-01-07T15:00:00.000Z", "In test"      , 5             , 5                   , 12],

  [1,          "2011-01-06T15:00:00.000Z", "2011-01-07T15:00:00.000Z", "Released"     , 5             , 0                   , 15],
  [2,          "2011-01-06T15:10:00.000Z", "2011-01-07T15:00:00.000Z", "Accepted"     , 3             , 0                   , 5],
  [4,          "2011-01-06T15:20:00.000Z", "2011-01-07T15:00:00.000Z", "In progress"  , 5             , 7                   , 15],
  [5,          "2011-01-06T15:30:00.000Z", "2011-01-07T15:00:00.000Z", "Ready to pull", 2             , 4                   , 4],

  [1,          "2011-01-07T15:00:00.000Z", "9999-01-01T00:00:00.000Z", "Released"     , 5            , 0                    , 15],
  [2,          "2011-01-07T15:10:00.000Z", "9999-01-01T00:00:00.000Z", "Released"     , 3            , 0                    , 5],
  [3,          "2011-01-07T15:20:00.000Z", "9999-01-01T00:00:00.000Z", "Accepted"     , 5            , 0                    , 12],
  [4,          "2011-01-07T15:30:00.000Z", "9999-01-01T00:00:00.000Z", "In test"      , 5            , 3                    , 15]  # Note: ObjectID 5 deleted
]

snapshots = lumenize.csvStyleArray_To_ArrayOfMaps(snapshotsCSV)

exports.snapshotsTest =

  postAndGetSnapshots: (test) ->

    client = restify.createJsonClient({
      url: 'http://localhost:1338',
      version: '*'
    })

    orgID = documentdb.Base.generateGuidId()

    body =
      orgID: orgID
      snapshots: snapshots

    client.post('/snapshot', body, (err, req, res, obj) ->
      if err?
        console.log(JSON.stringify(err))
        throw new Error(JSON.stringify(err))
      # TODO: Now test if they really got there by reading
      test.equal(obj.memo.totalCount, snapshots.length)
      query =
        _OrgID: orgID
      queryString = JSON.stringify(query)
      client.get('/snapshot?query=' + queryString, (err, req, res, obj) ->
        if err?
          console.log(JSON.stringify(err, null, 2))
          throw new Error(err)
        test.equal(obj.memo.snapshots.length, snapshots.length)
        fieldsToCheck = ["ObjectID", "_ValidFrom", "_ValidTo", "ScheduleState", "PlanEstimate", "TaskRemainingTotal", "TaskEstimateTotal"]
        for actualRow, index in obj.memo.snapshots
          expectedRow = snapshots[index]
          for field in fieldsToCheck
            test.equal(actualRow[field], expectedRow[field])
          test.ok(actualRow._OrgID?)
          test.ok(actualRow.id?)
          test.ok(! actualRow._etag?)
          test.ok(! actualRow._rid)
          test.ok(! actualRow._ts)
          test.ok(! actualRow._self)
          test.ok(! actualRow._attachments)
        # Now delete all of these from this test run
        client.del('/org/' + orgID, (err, req, res, obj) ->
          if err?
            console.log(JSON.stringify(err.message, null, 2))
            throw new Error(err)
          else
            test.equal(obj.memo.rowsDeleted, snapshots.length)
          test.done()
        )
      )
    )

