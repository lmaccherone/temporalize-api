path = require('path')
randomSalt = require(path.join(__dirname, '..', 'mixins', 'randomSalt'))

exports.randomSaltTest =

  randomSaltTest: (test) ->
    salt = randomSalt(64000)
    map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    counts = {}
    for char in salt
      if counts[char]?
        counts[char]++
      else
        counts[char] = 1
    for char in map
      test.ok(900 < counts[char] < 1100)

    test.done()

