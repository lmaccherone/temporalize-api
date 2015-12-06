# TODO: Refactor to use the loadSprocs function from documentdb-utils
# TODO: Upgrade to accept parameters for databaseID and collectionID
path = require('path')
fs = require('fs')
documentDBUtils = require('documentdb-utils')
expandSproc = require('./expandSproc')

collectionLink = null

loadSprocFromFile = (sprocFile, callback) ->
  {sprocString, sprocName} = expandSproc(sprocFile)

  config =
    storedProcedureID: sprocName
    storedProcedureJS: sprocString
    memo: null

  if collectionLink?
    config.collectionLink = collectionLink
  else
    config.databaseID = 'test-stored-procedure'  # TODO: Need to parameterize this. What do we do when we have more than one db?
    config.collectionID = 'test-stored-procedure'

  documentDBUtils(config, (err, response) ->
    if err?
      throw new Error(err)
    else
      collectionLink = response.collectionLink
      callback(sprocName, response.storedProcedureLink)
  )

getHandler = (storedProcedureLink, storedProcedureName) ->
  handler = (req, res, next) ->
    config =
      storedProcedureLink: storedProcedureLink
      # Note, the line below assumes that the body/queryParser uses mapParams = false
      memo: {params: req.params, query: req.query, body: req.body or {}, authorization: req.authorization}
#      debug: true

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

module.exports = (sprocDirectory, server, callback) ->
  sprocLinks = {}
  sprocFiles = fs.readdirSync(sprocDirectory)
  fullSprocFiles = []
  for sprocFile in sprocFiles
    fullFilePath = path.join(sprocDirectory, sprocFile)
    fullSprocFiles.push(fullFilePath)

  loadOneSproc = (callback) ->
    if fullSprocFiles.length > 0
      sprocFile = fullSprocFiles.pop()
      loadSprocFromFile(sprocFile, (sprocName, sprocLink) ->
        sprocLinks[sprocName] = sprocLink
        dashIndex = sprocName.indexOf('-')
        routeMethod = sprocName.substr(0, dashIndex)
        routeEntity = sprocName.substr(dashIndex + 1)
        handler = getHandler(sprocLink, sprocName)
        switch routeMethod
          when 'del', 'put'
            server.del('/' + routeEntity + '/:link', handler)
          when 'get'
            server.get('/' + routeEntity + '/:link', handler)
            server.get('/' + routeEntity, handler)
          when 'post'
            server.post('/' + routeEntity + '/:link', handler)
            server.post('/' + routeEntity, handler)
          else
            console.log('Warning, unrecognized routeMethod: ' + routeMethod + 'for ' + sprocName)
        if fullSprocFiles.length > 0
          loadOneSproc(callback)
        else
          server.locals.sprokLinks = sprocLinks
          callback()
      )

  loadOneSproc(callback)
