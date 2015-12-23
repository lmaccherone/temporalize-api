{getLink, WrappedClient} = require('documentdb-utils')

username = process.env.TEMPORALIZE_USERNAME
password = process.env.TEMPORALIZE_PASSWORD

urlConnection = process.env.DOCUMENT_DB_URL
masterKey = process.env.DOCUMENT_DB_KEY
auth = {masterKey}
client = new WrappedClient(urlConnection, auth)

module.exports =
  getSetUp: (client) ->
    setUp = (callback) ->
      console.log('starting setUp')
      client.basicAuth(username, password)
      client.post('/delete-partition', {username, password}, (err, req, res, obj) ->
        if err?
          throw new Error(err)
        else
          console.log('Partition deleted')
          client.post('/initialize-partition', {}, (err, req, res, obj) ->
            if err?
              throw new Error(err)
            else
              console.log("Partition initialized at beginning")
              callback()
          )
      )
    return setUp

  getTearDown: (client) ->
    tearDown = (callback) ->
      client.basicAuth(username, password)
      client.post('/delete-partition', (err, req, res, obj) ->
        if err?
          throw new Error(err)
        else
          console.log("Partition deleted at end")
          callback()
      )
    return tearDown

  getSESetUp: (config) ->
    setUp = (callback) ->
      console.log('in setUp')
      client.deleteDatabase(getLink(config.firstTopLevelID), () ->
        console.log('Partition deleted at beginning')
        callback()
      )
    return setUp

  getSETearDown: (config) ->
    tearDown = (callback) ->
      console.log('in tearDown')
      f = () ->
        client.deleteDatabase(getLink(config.firstTopLevelID), () ->
          callback()
        )
      setTimeout(f, config.refreshConfigMS + 500)
    return tearDown

