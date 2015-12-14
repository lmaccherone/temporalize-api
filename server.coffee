restify = require("restify")
fs = require('fs')
path = require('path')
StorageEngine = require(path.join(__dirname, 'src', 'StorageEngine'))

loadEndpoints = require(path.join(__dirname, 'src', 'loadEndpoints'))

se = null
seConfig =
  terminate: false
  debug: false

port = process.env.PORT or 1338

server = restify.createServer(
  name: 'temporalize'
  version: "0.1.0"
)
server.use(restify.authorizationParser())
server.use(restify.bodyParser({mapParams: false}))
server.use(restify.queryParser({mapParams: false}))
server.locals = {}


se = new StorageEngine(seConfig, () ->
  sprocsDirectory = path.join(__dirname, 'sprocs')
  se.loadSprocs(sprocsDirectory, (err, result) ->
    loadEndpoints(server, se, (err) ->
      if err?
        console.dir(err)
        throw new Error("Got error trying to loadEndpoints")
      server.listen(port, () ->
        console.log("%s listening at %s", server.name, server.url)
      )
    )
  )
)