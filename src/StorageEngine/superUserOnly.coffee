

module.exports =

  initializePartition: (username, password, callback) ->
    if process.env.NODE_ENV is 'production'
      return callback("initializePartition is not supported in production")
    if username is process.env.TEMPORALIZE_USERNAME and password is process.env.TEMPORALIZE_PASSWORD
      @terminate = false  # TODO: This is a potential race condition. It could attempt an operation before the database is ready. Consider moving @terminate=false into _initialize, but make sure that we fix the tests that set @terminate=true at the beginngin of execution, if there are any.
      @_initialize((err, result) ->
        if err?
          callback(err)
        else
          callback(null, result)
      )
    else
      callback({code: 401, body: "Invalid login for initializeTestPartition"})

  deletePartition: (username, password, callback) ->
    if process.env.NODE_ENV is 'production'
      return callback("deletePartition is not supported in production")
    @terminate = true
    if username is process.env.TEMPORALIZE_USERNAME and password is process.env.TEMPORALIZE_PASSWORD
      @client.deleteDatabase(getLink(@firstTopLevelID), (err, result) ->
        if err? and err.code isnt 404
          callback(err)
        else
          callback(null, result)
      )
    else
      callback({code: 401, body: "Invalid login for deletePartition"})