module.exports = (count) ->
  map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  chars = []
  for i in [0...count]
    chars.push(map.charAt(Math.floor(Math.random() * 64)))

  return chars.join('')