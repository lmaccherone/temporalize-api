path = require('path')
restify = require('restify')
common = require(path.join(__dirname, 'common'))

client = restify.createJsonClient({
  url: 'http://localhost:1338',
  version: '*'
})
username = process.env.TEMPORALIZE_USERNAME
password = process.env.TEMPORALIZE_PASSWORD

tenant = {name: 'Acme, Inc.'}
adminUser = {username: 'username', password: 'hello there'}

module.exports =

  setUp: common.getSetUp(client)

  theTest: (test) ->

    client.post('/create-tenant', {tenant, adminUser}, (err, req, res, obj) ->
      if err?
        console.dir(err)
        throw new Error("Got unexpeced error trying to upsert first tenant")
      {adminUser, tenant} = obj

      client.post('/login', {username, password}, (err, req, res, obj) ->
        if err?
          console.dir(err)
          throw new Error("Got unexpeced error trying to login as super-user")
        session = obj
        query = {_TenantID: tenant._TenantID}
        client.post('/query', {sessionID: session.id, query: {query}}, (err, req, res, obj) ->
          if err?
            console.dir(err)
            throw new Error("Got unexected error trying to execute query")

          if obj.all[0]._IsTemporalizeTenant
            tenantFromQuery = obj.all[0]
            userFromQuery = obj.all[1]
          else
            tenantFromQuery = obj.all[1]
            userFromQuery = obj.all[0]

          test.ok(userFromQuery._IsTemporalizeUser)
          test.equal(userFromQuery.username, adminUser.username)

          test.equal(tenantFromQuery.name, tenant.name)

          test.equal(userFromQuery._TenantID, tenantFromQuery._TenantID)
          test.equal(tenantFromQuery._EntityID, tenantFromQuery._TenantID)

          test.done()
        )
      )
    )

  tearDown: common.getTearDown(client)


