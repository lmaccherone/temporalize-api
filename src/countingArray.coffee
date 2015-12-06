module.exports = (count) ->
  output = []
  for i in [0..count - 1]
    output.push(String(i))
  return output