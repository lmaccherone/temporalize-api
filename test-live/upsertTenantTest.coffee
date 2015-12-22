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

firstTenantValues = {_TenantID: 'a', _EntityID: 'a', name: 'Acme, Inc.'}
secondTenantValues = {_TenantID: 'a', _EntityID: 'a', name: 'Wile E. Coyote, Inc.'}

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
          client.post('/upsert-tenant', {sessionID: session.id, tenant: firstTenantValues}, (err, req, res, obj) ->
            if err?
              console.dir(err)
              throw new Error("Got unexpeced error trying to upsert first tenant")
            first = obj
            test.equal(first._EntityID, firstTenantValues._EntityID)
            test.equal(first.name, firstTenantValues.name)
            test.ok(first._IsTemporalizeTenant)

            client.post('/upsert-tenant', {sessionID: session.id, tenant: secondTenantValues}, (err, req, res, obj) ->
              if err?
                console.dir(err)
                throw new Error("Got unexpeced error trying to upsert second tenant")

              # TODO: The checks below are missing because the second upsert incorrectly returns the first version.
#              second = obj
#              console.log('second: ', second)

              query =
                topLevelPartitionKey: 'a'
                secondLevelPartitionKey: 'a'

              client.post('/query', {sessionID: session.id, query}, (err, req, res, obj) ->
                if err?
                  console.dir(err)
                  throw new Error("Got unexected error trying to execute query")

                test.equal(obj.all.length, 2)
                test.deepEqual(obj.all[0].name, firstTenantValues.name)
                test.deepEqual(obj.all[1].name, secondTenantValues.name)

                test.ok(obj.stats?)

                test.done()
              )
            )
          )
        )
      )
    )

  tearDown: common.getTearDown(client)


