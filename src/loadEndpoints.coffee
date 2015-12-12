# TODO: Refactor to use the loadSprocs function from documentdb-utils
# TODO: Upgrade to accept parameters for databaseID and collectionID
path = require('path')
fs = require('fs')
{getLink, getLinkArray} = require('documentdb-utils')

module.exports = (server, se, callback) ->
  server.get('/hello', (req, res, next) ->
    res.send(200, {hello: 'world'})
  )

  server.post('/login', (req, res, next) ->
    username = req.authorization.basic.username or req.body.username
    password = req.authorization.basic.password or req.body.password
    se.login(username, password, (err, response) ->
      if err?
        res.send(err.code, err.body)
      else
        res.send(200, response)
        next()
    )
  )

  server.post('/upsert-user', (req, res, next) ->
    sessionID = req.body.sessionID
    user = req.body.user
    se.upsertUser(sessionID, user, (err, response) ->
      if err?
        res.send(err.code, err.body)
      else
        res.send(200, response)
        next()
    )
  )

  server.post('/delete-partition', (req, res, next) ->
    username = req.authorization.basic.username
    password = req.authorization.basic.password
    se.deletePartition(username, password, (err, response) ->
      if err?
        res.send(err.code, err.body)
      else
        res.send(200, response)
        next()
    )
  )

  server.post('/initialize-partition', (req, res, next) ->
    username = req.authorization.basic.username
    password = req.authorization.basic.password
    se.initializePartition(username, password, (err, response) ->
      if err?
        res.send(err.code, err.body)
      else
        res.send(200, response)
        next()
    )
  )

  callback()

