# TODO: Refactor to use the loadSprocs function from documentdb-utils
# TODO: Upgrade to accept parameters for databaseID and collectionID
path = require('path')
fs = require('fs')
restify = require('restify')
{getLink, getLinkArray} = require('documentdb-utils')

module.exports = (server, se, callback) ->

  getStandardCallback = (req, res, next) ->
    standardCallback = (err, response) ->
      if err?
        res.send(err.code, err.body)
      else
        res.send(200, response)
        next()
    return standardCallback

  server.get('/hello', (req, res, next) ->
    res.send(200, {hello: 'world'})
  )

  server.get('/env', (req, res, next) ->
    username = req.authorization?.basic?.username or req.body.username
    password = req.authorization?.basic?.password or req.body.password
    sysUsername = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
    sysPassword = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
    if username is sysUsername and password is sysPassword
      reply = {}
      for key, value of process.env
        reply[key] = value

      res.send(200, reply)
      next()
    else
      res.send(401, "Must provide super-user credentials for this operation")
  )

  server.get(/\/?.*/, restify.serveStatic({
    directory: path.join('.', 'material-ui', 'temporalize-ui', 'build'),
    default: 'index.html'
  }))

  server.post('/login', (req, res, next) ->
    username = req.authorization?.basic?.username or req.body.username
    password = req.authorization?.basic?.password or req.body.password
#    se.login(username, password, getStandardCallback(req, res, next))
    se.login(username, password, getStandardCallback(req, res, next))
  )

  server.post('/query', (req, res, next) ->
    sessionID = req.body.sessionID
    query = req.body.query
    se.query(sessionID, query, getStandardCallback(req, res, next))
  )

  server.post('/upsert-user', (req, res, next) ->
    sessionID = req.body.sessionID
    user = req.body.user
    se.upsertUser(sessionID, user, getStandardCallback(req, res, next))
  )

  server.post('/upsert', (req, res, next) ->
    sessionID = req.body.sessionID
    if req.body.upsert?
      upserts = [req.body.upsert]
    else
      upserts = req.body.upserts
    se.upsert(sessionID, upserts, null, getStandardCallback(req, res, next))
  )

  server.post('/delete-partition', (req, res, next) ->
    username = req.authorization?.basic?.username or req.body.username   # TODO: Move this logic to the storage engine
    password = req.authorization?.basic?.password or req.body.password
    sysUsername = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
    sysPassword = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
    if username is sysUsername and password is sysPassword
      se.deletePartition(username, password, getStandardCallback(req, res, next))
    else
      res.send(401, "Must provide super-user credentials for this operation")
  )

  server.post('/initialize-partition', (req, res, next) ->
    username = req.authorization?.basic?.username or req.body.username
    password = req.authorization?.basic?.password or req.body.password
    sysUsername = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
    sysPassword = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
    if username is sysUsername and password is sysPassword
      se.initializePartition(username, password, getStandardCallback(req, res, next))
    else
      res.send(401, "Must provide super-user credentials for this operation")
  )

  server.post('/execute-sproc', (req, res, next) ->
    username = req.authorization?.basic?.username or req.body.username
    password = req.authorization?.basic?.password or req.body.password
    sysUsername = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
    sysPassword = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
    if username is sysUsername and password is sysPassword
      memo = req.body.memo
      if req.body.sprocName?
        se.executeSproc(req.body.sprocName, memo, getStandardCallback(req, res, next))
      else
        res.send(400, "Must provide a sprocName field in the body")
    else
      res.send(401, "Must provide super-user credentials for this operation")
  )

  server.post('/load-sprocs', (req, res, next) ->
    username = req.authorization?.basic?.username or req.body.username
    password = req.authorization?.basic?.password or req.body.password
    sysUsername = process.env.APPSETTING_TEMPORALIZE_USERNAME or process.env.TEMPORALIZE_USERNAME
    sysPassword = process.env.APPSETTING_TEMPORALIZE_PASSWORD or process.env.TEMPORALIZE_PASSWORD
    if username is sysUsername and password is sysPassword
      sprocsDirectory = path.join(__dirname, '..', 'sprocs')
      se.loadSprocs(sprocsDirectory, getStandardCallback(req, res, next))
    else
      res.send(401, "Must provide super-user credentials for this operation")
  )

  server.post('/time-in-state', (req, res, next) ->
    sessionID = req.body.sessionID
    config = req.body.config
    if config?
      if sessionID?
        se.timeInState(sessionID, config, getStandardCallback(req, res, next))
      else
        username = req.authorization?.basic?.username or req.body.username  # TODO: Move this logic to the StorageEngine
        password = req.authorization?.basic?.password or req.body.password
        se.login(username, password, (err, result) ->
          if err?
            res.send(err.code, err.body)
          else
            se.timeInState(result.id, config, getStandardCallback(req, res, next))
        )
    else
      res.send(400, "Must provide a config field in the body")
  )

  server.post('/time-series', (req, res, next) ->
    sessionID = req.body.sessionID
    config = req.body.config
    if config?
      if sessionID?
        se.timeSeries(sessionID, config, getStandardCallback(req, res, next))
      else
        username = req.authorization?.basic?.username or req.body.username  # TODO: Move this logic to the StorageEngine
        password = req.authorization?.basic?.password or req.body.password
        se.login(username, password, (err, result) ->
          if err?
            res.send(err.code, err.body + username + password)
          else
            se.timeSeries(result.id, config, getStandardCallback(req, res, next))
        )
    else
      res.send(400, "Must provide a config field in the body")
  )

  callback()

