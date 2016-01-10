React = require('react')

ReactHighcharts = require('react-highcharts/bundle/highcharts')
require('highcharts-exporting')
require('highcharts-more')

_ = require('lodash')
diff = require("rfc6902-json-diff")
superagent = require('superagent/lib/client')  # TODO: Use my abstracted api-request

{Mixins, Paper} = require('material-ui')
{StyleResizable} = Mixins

tipCalculator = require('./tipCalculator')
request = require('../../../api-request')
JSONStorage = require('../../../JSONStorage')

deepEqual = (obj1, obj2) ->
  return _.where([obj1], obj2).length is 1

TiPChart = React.createClass(

  getInitialState: () ->
    cachedConfig = JSONStorage.getItem('tip')  # TODO: Update this to be a hash of 'tip' + @state.userConfig
    unless cachedConfig?
      cachedConfig = {}
    return {config: cachedConfig}

  componentDidMount: () ->
    if @isMounted()
      cachedConfig = JSONStorage.getItem('tip')  # TODO: Use the hash
      unless cachedConfig?
       cachedConfig = {}
      unless deepEqual(cachedConfig, @state.config)
        @setState({config: cachedConfig})

      lumenizeCalculatorConfig = {
        "config": {
          "query": {"Priority": 1},
          "stateFilter": {"State": {"$in": ["In Progress", "Accepted"]}},
          "granularity": "hour",
          "tz": "America/Chicago",
          "endBefore": "2015-12-18T03:36:12.662Z",
          "uniqueIDField": "_EntityID",
          "trackLastValueForTheseFields": ["_ValidTo", "Points"]
        }
      }

      request("/time-in-state", lumenizeCalculatorConfig, (err, response) =>
        if @isMounted()
          calculatorResults = tipCalculator({userConfig: @state.userConfig, lumenizeCalculatorConfig}, response.body)
          series = calculatorResults.series

          scatterChartConfig = {

            chart: {
              type: 'bubble',
              zoomType: 'x'
            },
            legend: {
              enabled: true
            },
            title: {
              text: 'Time in Process (TiP)'
            },
            subtitle: {
              text: ''
            },
            xAxis: {
              type: 'datetime'
            },
            yAxis: {
              title: {
                text: 'Weeks in process'
              },
              min: 0
            },
            tooltip: {
              useHTML: true,
              headerFormat: '<table>',
              pointFormat: '<tr><th colspan="2"><h3>{point.name}</h3></th></tr>' +
                '<tr><th>Last in process:</th><td>{point.dateLabel}</td></tr>' +
                '<tr><th>Weeks in process:</th><td>{point.y}</td></tr>' +
                '<tr><th>Size:</th><td>{point.z}</td></tr>',
              footerFormat: '</table>',
              followPointer: true
            },
            series: series
          }

          unless deepEqual(cachedConfig, scatterChartConfig)
            JSONStorage.setItem('tip', scatterChartConfig)  # TODO: Use hash
            @setState({
              config: scatterChartConfig
            })
      )

  render: () ->
    return (
      <div>
        <ReactHighcharts width="66%" config={@state.config} ref="chart"></ReactHighcharts>
      </div>
    )
)

module.exports = React.createClass(

  mixins: [StyleResizable]

  getStyles: () ->
    styles =
      # root:
      #   height: '100px'
      #   width: '100px'
      #   margin: '0 auto'
      #   marginBottom: '64px'
      #   textAlign: 'center'
      group:
        float: 'left'
        width: '100%'
      # p:
      #   lineHeight: '80px'
      #   height: '100%'

    if @isDeviceSize(StyleResizable.statics.Sizes.MEDIUM)
      styles.group.width = '33%'

    return styles

  # TODO: Set userConfig from the UI filter settings

  render: () ->

    groupStyle = @getStyles().group

    return (
      <Paper style = {{marginBottom: '22px'}}>
        <TiPChart userConfig={@state.userConfig}/>
      </Paper>
    )
)
