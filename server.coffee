restify = require("restify")
fs = require('fs')
path = require('path')

loadEndpoints = require(path.join(__dirname, 'src', 'loadEndpoints'))

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
# Load sprocs once we have them

loadEndpoints(server, se, (err) ->
  if err?
    console.dir(err)
    throw new Error("Got error trying to loadEndpoints")
  server.listen(port, () ->
    console.log("%s listening at %s", server.name, server.url)
  )
)