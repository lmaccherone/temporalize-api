React = require('react')

ReactHighcharts = require('react-highcharts/bundle/highcharts')
require('highcharts-exporting')
require('highcharts-more')

_ = require('lodash')
diff = require("rfc6902-json-diff")
superagent = require('superagent/lib/client')

{Mixins, Paper} = require('material-ui')
{StyleResizable} = Mixins

tipCalculator = require('./tipCalculator')

deepEqual = (obj1, obj2) ->
  return _.where([obj1], obj2).length is 1

TiPChart = React.createClass(

  getInitialState: () ->
    cachedConfig = JSON.parse(localStorage.getItem('tip'))  # TODO: Update this to be a hash of 'tip' + @state.userConfig
    unless cachedConfig?
      cachedConfig = {}
      console.log('no config in localStorage')
    return {config: cachedConfig}

  componentDidMount: () ->
    if @isMounted()
      cachedConfig = JSON.parse(localStorage.getItem('tip'))  # TODO: Use the hash
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
      "username": "larry@maccherone.com"
      "password": "BCltsn3^LlMF"
    }

    superagent.post("/time-in-state").accept('json').send(lumenizeCalculatorConfig).end((err, response) =>
      if @isMounted()
        calculatorResults = tipCalculator({userConfig: @state.userConfig, lumenizeCalculatorConfig}, response.body)
        series = calculatorResults.series
        console.log('series: ', series)

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
            }
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
          # plotOptions: {
          #   series: {
          #     dataLabels: {
          #       enabled: true,
          #       format: '{point.name}'
          #     }
          #   }
          # },
          series: series
        }

        if deepEqual({a:1}, {b:2})
          console.log('is equal', deepEqual({a:1}, {b:2}))
        unless deepEqual(cachedConfig, scatterChartConfig)
          localStorage.setItem('tip', JSON.stringify(scatterChartConfig))  # TODO: Use hash
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
