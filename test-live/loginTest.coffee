restify = require('restify')

username = process.env.TEMPORALIZE_USERNAME
password = process.env.TEMPORALIZE_PASSWORD

client = restify.createJsonClient({
  url: 'http://localhost:1338',
  version: '*'
})

module.exports =

  successful: (test) ->

    client.basicAuth(username, password)
    client.post('/login', null, (err, req, res, obj) ->
      if err?
        console.dir(err)
        throw new Error("Got unexpeced error trying to login")

      session = obj
      test.ok(session._IsSession)
      test.ok(session._Created <= new Date().toISOString())
      user = session.user
      test.equal(user.username, username)

      code = res.statusCode
      test.equal(code, 200)

      test.done()
    )

  badPassword: (test) ->
    client.basicAuth(username, 'junk')
    client.post('/login', null, (err, req, res, obj) ->
      test.equal(err.statusCode, 401)
      test.equal(err.body, "Password does not match")
      test.done()
    )

  badUsername: (test) ->
    client.basicAuth('not me', password)
    client.post('/login', null, (err, req, res, obj) ->
      test.equal(err.statusCode, 401)
      test.equal(err.body, "Couldn't find user with username: not me")
      test.done()
    )