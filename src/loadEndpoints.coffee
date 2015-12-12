# TODO: Refactor to use the loadSprocs function from documentdb-utils
# TODO: Upgrade to accept parameters for databaseID and collectionID
path = require('path')
fs = require('fs')
{getLink, getLinkArray} = require('documentdb-utils')

getHandler = (endPoint) ->
  handler = (req, res, next) ->

    documentDBUtils(config, (err, response, stats) ->
      if err?
        throw new Error(err)
        throw new Error("Error calling stored procedure #{storedProcedureName}\n#{JSON.stringify(err, null, 2)}")
#      next.ifError(err)  # TODO: Need to figure out why using this doesn't hang up the connection. Maybe I need to add a post-error handler.
      toReturn =
        body: response
        stats: stats
      res.send(200, toReturn)
      next()
    )
  return handler

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

  server.post('/upsert', (req, res, next) ->
    console.log(req)
#    se.query(req.authorization.basic.username, req.authorization.basic.password, (err, response) ->
#      if err?
#        res.send(err.code, err.body)
#      else
#        res.send(200, response)
#        next()
#    )
  )

  callback()

