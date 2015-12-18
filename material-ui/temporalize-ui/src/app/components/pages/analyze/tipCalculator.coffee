#lumenize = require('lumenize')
# TODO: Need to figure out how to deal with the tz files and restore access to lumenize

module.exports = (config, calculatorResults) ->

  console.log('got inside tipCalculator')

  # override
  # Transform the data into whatever form your visualization expects from the data in the @lumenizeCalculator
  # Store your calculations into @visualizationData, which will be sent to the visualization create and update callbacks.
  # Try to fully populate the x-axis based upon today even if you have no data for later dates yet.

#  calculatorResults = @lumenizeCalculator.getResults()

  #    if config.debug
  #      console.log('length of calculatorResults before @currentObjectID filtering: ', calculatorResults.length)
  #    calculatorResults = (r for r in calculatorResults when r.ObjectID in @currentObjectIDs)
  #    if config.debug
  #      console.log('length of calculatorResults after @currentObjectID filtering: ', calculatorResults.length)

  if calculatorResults.length == 0
    throw new Error('no calculatorResults')
  else
    @virgin = false
    inProcessItems = []
    notInProcessItems = []

    if config.asOf?
#      asOfMilliseconds = new lumenize.Time(config.asOf, 'millisecond', config.lumenizeCalculatorConfig.tz).getJSDate(config.lumenizeCalculatorConfig.tz).getTime()
      asOfMilliseconds = new Date(config.asOf).getTime()
    else
      asOfMilliseconds = new Date().getTime()
    millisecondsToShow = config.userConfig.daysToShow * 1000 * 60 * 60 * 24
    startMilliseconds = asOfMilliseconds - millisecondsToShow
    for row in calculatorResults
#      jsDateMilliseconds = new lumenize.Time(row._ValidTo_lastValue, 'millisecond', config.lumenizeCalculatorConfig.tz).getJSDate(config.lumenizeCalculatorConfig.tz).getTime()
      jsDateMilliseconds = new Date(row._ValidTo_lastValue).getTime()
      if jsDateMilliseconds > asOfMilliseconds
        row.x = asOfMilliseconds
      else
        row.x = jsDateMilliseconds
      row.x -= Math.random() * 1000 * 60 * 60 * 24  # Separate data points that show up on top of each other
      if config.radiusField?
        row.marker = {radius: config.radiusField.f(row[config.radiusField.field + "_lastValue"])}
      if jsDateMilliseconds > startMilliseconds
        if jsDateMilliseconds < asOfMilliseconds
          notInProcessItems.push(row)
        else
          inProcessItems.push(row)

    # calculating workHours from workDayStartOn and workDayEndBefore
    startOnInMinutes = config.userConfig.workDayStartOn.hour * 60
    if config.userConfig.workDayStartOn?.minute
      startOnInMinutes += config.userConfig.workDayStartOn.minute
    endBeforeInMinutes = config.userConfig.workDayEndBefore.hour * 60
    if config.userConfig.workDayEndBefore?.minute
      endBeforeInMinutes += config.userConfig.workDayEndBefore.minute
    if startOnInMinutes < endBeforeInMinutes
      workMinutes = endBeforeInMinutes - startOnInMinutes
    else
      workMinutes = 24 * 60 - startOnInMinutes
      workMinutes += endBeforeInMinutes
    workHours = workMinutes / 60

    # converting ticks (hours) into days and adding to inProcessItems
    for row in inProcessItems
      row.days = row.ticks / workHours
      console.log('row.days', row.days)
    for row in notInProcessItems
      row.days = row.ticks / workHours

#  histogramResults = lumenize.histogram(notInProcessItems, 'days')
#  unless histogramResults?
#    if config.debug
#      console.log('No histogramResults. Returning.')
#    return
#
#  {buckets, chartMax, valueMax, bucketSize, clipped} = histogramResults
#
#  histogramCategories = []
#  histogramData = []
#  for b in buckets
#    histogramCategories.push(b.label)
#    histogramData.push(b.count)
  chartMax = 100

  for row in notInProcessItems
    row.y = row.clippedChartValue
  for row in inProcessItems
    if row.days > chartMax
      row.y = chartMax
    else
      row.y = row.days
  #      console.log(row)

  series = [
    {name: 'Not in Process', data: notInProcessItems},
    {name: 'In Process', data: inProcessItems},
    {name: 'Percentile', data: [], yAxis: 1, showInLegend: false}
  ]

#  visualizationData = {series, histogramResults, histogramCategories, histogramData, startMilliseconds, asOfMilliseconds}
  visualizationData = {series, startMilliseconds, asOfMilliseconds}
  return visualizationData
