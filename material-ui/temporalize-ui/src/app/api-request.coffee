superagent = require('superagent/lib/client')
history = require('./history')

module.exports = (endpoint, body, callback) ->
  ###
  Assumes you want GET if body is missing, otherwise uses POST
  ###
  unless callback?
    callback = body
    body = null

  session = JSON.parse(localStorage.getItem('session'))
  console.log('endpoint', endpoint)
  console.log('session', session)
  if session?.id? or endpoint is '/login'
    if body?
      if session?.id?
        body.sessionID = session.id
      superagent.post(endpoint).accept('json').send(body).end((err, response) ->
        if err?
          if err.status is 401
            localStorage.removeItem('session')
            history.replace('/login')
        else
          if callback?
            callback(err, response)
      )
  else  # No session?.id
    localStorage.removeItem('session')
    history.replace('/login')
