restify = require("restify")
fs = require('fs')
path = require('path')

#hello = require("./src/hello")
#snapshotApi = require("./src/snapshotApi")
loadSprocs = require("./src/createServerEndpointForEachSproc")

port = process.env.PORT or 1338

server = restify.createServer(
  name: 'temporalize'
  version: "0.1.0"
)
server.use(restify.authorizationParser())
server.use(restify.bodyParser({mapParams: false}))
server.use(restify.queryParser({mapParams: false}))
server.locals = {}

sprocDirectory = path.join(__dirname, 'sprocs')
loadSprocs(sprocDirectory, server, () ->
  server.listen(port, () ->
    console.log("%s listening at %s", server.name, server.url)
  )
)