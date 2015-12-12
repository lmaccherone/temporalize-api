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
    se.login(req.authorization.basic.username, req.authorization.basic.password, (err, response) ->
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

  server.post('/delete-test-database', (req, res, next) ->
    username = req.authorization.basic.username
    password = req.authorization.basic.password
    se.deleteTestDatabase(username, password, (err, response) ->
      if err?
        res.send(err.code, err.body)
      else
        res.send(200, response)
        next()
    )
  )

  server.post('/initialize-test-database', (req, res, next) ->
    username = req.authorization.basic.username
    password = req.authorization.basic.password
    se.initializeTestDatabase(username, password, (err, response) ->
      if err?
        res.send(err.code, err.body)
      else
        res.send(200, response)
        next()
    )
  )



  callback()

