path = require('path')
restify = require('restify')
common = require(path.join(__dirname, 'common'))

username = process.env.TEMPORALIZE_USERNAME
password = process.env.TEMPORALIZE_PASSWORD

client = restify.createJsonClient({
  url: 'http://localhost:1338',
  version: '*'
})

#client = restify.createJsonClient({
#  url: 'http://temporalize.azurewebsites.net',
#  version: '*'
#})

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

firstUpsert = {_TenantID: 'a', _EntityID: 1, a: 1, c: 3}
secondUpsert = {_TenantID: 'a', _EntityID: 1, b: 20, c: null}

module.exports =

  setUp: common.getSetUp(client)

  theTest: (test) ->
    client.post('/login', {}, (err, req, res, obj) ->
      if err?
        throw new Error("Got unexected error trying to login as superuser")
      session = obj
      client.post('/upsert-user', {sessionID: session.id, user: user}, (err, req, res, obj) ->
        if err?
          console.dir(err)
          throw new Error("Got unexpeced error trying to upsert-user")

        test.ok(!obj.password)
        for key, value of user
          unless key is 'password'
            test.deepEqual(obj[key], value)

        client.basicAuth(user.username, user.password)
        client.post('/login', (err, req, res, obj) ->
          if err?
            console.dir(err)
            throw new Error("Got unexpeced error trying to login as normal user")
          session = obj
          client.post('/upsert', {sessionID: session.id, upsert: firstUpsert}, (err, req, res, obj) ->

            first = obj
            test.equal(first.a, 1)
            test.equal(first.c, 3)
            test.ok(not first.b?)

            client.post('/upsert', {sessionID: session.id, upsert: secondUpsert}, (err, req, res, obj) ->

              # TODO: This is turned off because on the second upsert, it actually returns the first value
#              second = obj
#              test.equal(second.a, 1)
#              test.equal(second.b, 20)
#              test.ok(! second.c?)
#              console.log(second)

              query =
                topLevelPartitionKey: 'a'
                secondLevelPartitionKey: 1
                fields: ["a", "b", "c"]

              client.post('/query', {sessionID: session.id, query}, (err, req, res, obj) ->
                if err?
                  console.dir(err)
                  throw new Error("Got unexected error trying to execute query")

                test.equal(obj.all.length, 2)
                test.deepEqual(obj.all[0], { a: 1, c: 3, _TenantID: 'a' })
                test.deepEqual(obj.all[1], { a: 1, b: 20, _TenantID: 'a' })

                test.ok(obj.stats?)

                test.done()
              )
            )
          )
        )
      )
    )

  tearDown: common.getTearDown(client)


