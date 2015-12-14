restify = require("restify")
fs = require('fs')
path = require('path')
lumenize = require('lumenize')
marked = require('marked')

{_} = require('documentdb-utils')

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
  formatters: {
    'application/json': (req, res, body, cb) ->
      if body instanceof Error
        res.statusCode = body.statusCode or 500
        if body.body
          body = body.body
        else
          body = {message: body.message}

      else if Buffer.isBuffer(body)
        body = body.toString('base64')

      data = JSON.stringify(body) + 'something'
      res.setHeader('Content-Length', Buffer.byteLength(data))

      return cb(null, data)

    'text/plain': (req, res, body, cb) ->
      if body instanceof Error
        res.statusCode = body.statusCode or 500
        body = body.message
      else if typeof(body) is 'object'
        if body.seriesData?
          data = body.seriesData
        else if _.isArray(body)
          data = body
        else
          body = JSON.stringify(body)
      else
        body = body.toString()

      if data?
        body = lumenize.table.toString(data)

      res.setHeader('Content-Length', Buffer.byteLength(body))
      return cb(null, body)

    'text/html': (req, res, body, cb) ->
      if body instanceof Error
        res.statusCode = body.statusCode or 500
        body = body.message
      else if typeof(body) is 'object'
        if body.seriesData?
          data = body.seriesData
        else if _.isArray(body)
          data = body
        else
          body = JSON.stringify(body)
      else
        body = body.toString()

      if data?
        table = lumenize.table.toString(data)
        body = marked(table)

      res.setHeader('Content-Length', Buffer.byteLength(body))
      return cb(null, body)
  }
)

server.use(restify.acceptParser(server.acceptable))
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