restify = require('restify')

exports.getHelloTestLive =

  helloTest: (test) ->

    client = restify.createJsonClient({
      url: 'http://localhost:1338',
      version: '*'
    })

    client.get('/hello', (err, req, res, obj) ->
      test.deepEqual(obj, {hello: 'world'})
      test.done()

    )