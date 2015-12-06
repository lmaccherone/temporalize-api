# TODO: Refactor to use the loadSprocs function from documentdb-utils
# TODO: Upgrade to accept parameters for databaseID and collectionID
path = require('path')
fs = require('fs')
{getLink, getLinkArray} = require('documentdb-utils')

getHandler = (method) ->
  handler = (req, res, next) ->

    documentDBUtils(config, (err, response) ->
      if err?
        throw new Error(err)
        throw new Error("Error calling stored procedure #{storedProcedureName}\n#{JSON.stringify(err, null, 2)}")
#      next.ifError(err)  # TODO: Need to figure out why using this doesn't hang up the connection. Maybe I need to add a post-error handler.
      toReturn =
        memo: response.memo
        stats: response.stats
      res.send(200, toReturn)
      next()
    )
  return handler

module.exports = (server, se, callback) ->
  methods = [
    {methodName: 'upsertEntity', }
  ]
  server.post()

