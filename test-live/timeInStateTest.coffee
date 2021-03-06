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
secondUpsert = {_TenantID: 'a', _EntityID: 1, a: 10, b: 20, c: null}

module.exports =

  setUp: common.getSetUp(client)

  theTest: (test) ->
    client.post('/login', {}, (err, req, res, obj) ->
      if err?
        throw new Error("Got unexected error trying to login as superuser")
      session = obj
      client.post('/load-sprocs', (err, req, res, obj) ->
        client.post('/execute-sproc', {sprocName: 'simulateKanban', memo:{documentsDesired: 100, startDate: "2015-11-13"}}, (err, req, res, obj) ->
          if err?
            console.dir(err)
            throw new Error("Got unexected error trying to execute-sproc")
          client.post('/upsert-user', {sessionID: session.id, user: user}, (err, req, res, obj) ->
            if err?
              console.dir(err)
              throw new Error("Got unexpeced error trying to upsert-user")
            client.basicAuth(user.username, user.password)
            client.post('/login', (err, req, res, obj) ->
              if err?
                console.dir(err)
                throw new Error("Got unexpeced error trying to login as normal user")
              session = obj

              granularity = 'hour'
              tz = 'America/Chicago'
              today = new Date()

              tisConfig =
                query: {Priority: 1}
                granularity: granularity
                tz: tz
                endBefore: today.toISOString()
                uniqueIDField: '_EntityID'
                trackLastValueForTheseFields: ['_ValidTo', 'Points']
                stateFilter: {State: {$in: ['In Progress', 'Accepted']}}

              console.log(JSON.stringify(tisConfig, null, 2))

              client.post('/time-in-state', {sessionID: session.id, config: tisConfig}, (err, req, res, obj) ->
                if err?
                  console.dir(err)
                  throw new Error("Got unexected error trying to time-in-state")
                row.days = row.ticks / 8 for row in obj
                console.log(obj)

                test.done()
              )
            )
          )
        )
      )
    )

  tearDown: common.getTearDown(client)


