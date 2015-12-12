restify = require('restify')

username = process.env.TEMPORALIZE_USERNAME
password = process.env.TEMPORALIZE_PASSWORD

client = restify.createJsonClient({
  url: 'http://localhost:1338',
  version: '*'
})

client.basicAuth(username, password)

user =
  password: ';/klikl.o;/;'
  _EntityID: 100
  _TenantID: 'a'
  username: 'username'
  tenantIDsICanRead: ['a', 'b']
  tenantIDsICanWrite: ['a']
  tenantIDsICanAdmin: ['a']

session = null

module.exports =

  setUp: (callback) ->
    client.post('/delete-database', {databaseID: "A"}, (err, req, res, obj) ->
      if err?
        throw new Error(err)
      else
        client.post('/initialize-database', {}, (err, req, res, obj) ->
          if err?
            throw new Error(err)
          else
            console.log("Database initialized")
            callback()
        )
    )


  junk: (test) ->
    test.done()

#  someDocs: (test) ->
#
#    client.post('/upsert-user', {sessionID: session.id, user: user}, (err, req, res, obj) ->
#      if err?
#        console.dir(err)
#        throw new Error("Got unexpeced error trying to login")
#
#      test.ok(!obj.password)
#      for key, value of user
#        unless key is 'password'
#          test.deepEqual(obj[key], value)
#
#      test.done()
#    )

  tearDown: (callback) ->
    client.post('/delete-database', {databaseID: "A"}, (err, req, res, obj) ->
      if err?
        throw new Error(err)
      else
        console.log("Database deleted")
        callback()
    )

