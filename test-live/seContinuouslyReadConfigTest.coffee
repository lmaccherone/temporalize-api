path = require('path')
StorageEngine = require(path.join('..', 'src', 'StorageEngine'))
common = require(path.join(__dirname, 'common'))

se = null

config =
  firstTopLevelID: 'dev-test-database'
  firstSecondLevelID: 'dev-test-collection'
  terminate: false
  refreshConfigMS: 1000
  debug: false

exports.continuouslyReadTest =

  setUp: common.getSESetUp(config)

  theTest: (test) ->
    console.log('starting test')
    config.refreshConfigMS = 1000
    se = new StorageEngine(config, () ->
      start = new Date()
      count = 0
      se.readConfigContinuouslyEventHandler = () ->
        count++
        if count is 3
          se.terminate = true
          stop = new Date()
          console.log("Time to get 3 callbacks: #{stop - start}ms")
          test.ok(2000 < stop - start < 9000)
          test.done()
    )

  tearDown: common.getSETearDown(config)
