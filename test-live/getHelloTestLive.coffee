restify = require('restify')

exports.getHelloTestLive =

  helloTest: (test) ->

    client = restify.createJsonClient({
      url: 'http://localhost:1338',
      version: '*'
    })

    client.get('/hello', (err, req, res, obj) ->
      test.equal(obj.memo.response, 'Hello world.')
      test.done()

    )