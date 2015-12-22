#lumenize = require('lumenize')
# TODO: Need to figure out how to deal with the tz files and restore access to lumenize

module.exports = (config, calculatorResults) ->

  noLongerInProcess = []
  stillInProcess = []
  asOfDateString = "2015-12-18"  # TODO: Fix this
  asOfDate = new Date(asOfDateString).valueOf()
  for row in calculatorResults
    if row._ValidTo_lastValue > asOfDateString
      row.x = asOfDate
      row.dateLabel = 'still in process as of ' + asOfDateString.substring(0, 10)
      stillInProcess.push(row)
    else
      row.x = new Date(row._ValidTo_lastValue).valueOf()
      noLongerInProcess.push(row)
      row.dateLabel = row._ValidTo_lastValue.substring(0, 10)
    row.y = row.ticks / 8 / 5  # Assumes 5 work-day week and 8 hours per day  TODO: Upgrade to use config info
    row.z = row.Points_lastValue  # Assumes 5 work-day week and 8 hours per day

  series = [
    {name: 'No longer in process', data: noLongerInProcess}
    {name: 'Still in process', data: stillInProcess}
  ]

  return {series}
