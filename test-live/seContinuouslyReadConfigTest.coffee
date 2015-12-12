path = require('path')
StorageEngine = require(path.join('..', 'src', 'StorageEngine'))
{getLink, WrappedClient} = require('documentdb-utils')

se = null
client = null

config =
  firstTopLevelID: 'dev-test-database'
  firstSecondLevelID: 'dev-test-collection'
  terminate: false
  refreshConfigMS: 1000
  debug: false

exports.continuouslyReadTest =

  setUp: (callback) ->
    urlConnection = process.env.DOCUMENT_DB_URL
    masterKey = process.env.DOCUMENT_DB_KEY
    auth = {masterKey}
    client = new WrappedClient(urlConnection, auth)
    client.deleteTestPartition(getLink(config.firstTopLevelID), () =>
      callback()
    )

  theTest: (test) ->
    config.refreshConfigMS = 1000
    se = new StorageEngine(config, () =>
      start = new Date()
      count = 0
      se.readConfigContinuouslyEventHandler = () =>
        count++
        if count is 3
          se.terminate = true
          stop = new Date()
          console.log("Time to get 3 callbacks: #{stop - start}ms")
          test.ok(2000 < stop - start < 9000)
          test.done()
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteTestPartition(getLink(config.firstTopLevelID), () ->
        callback()
      )
    setTimeout(f, config.refreshConfigMS + 500)