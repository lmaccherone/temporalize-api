import React from 'react';

//import Highcharts from 'highcharts-release/highcharts.src.js';
//import More from 'highcharts-release/highcharts-more.src.js';
//import 'highcharts-release/modules/exporting.src.js';
//import ReactHighcharts from 'react-highcharts';

//import Highcharts from 'highcharts-release/highcharts.src.js';
import ReactHighcharts from 'react-highcharts/bundle/highcharts';
import 'highcharts-exporting';
import 'highcharts-more';

import _ from 'lodash';
import diff from "rfc6902-json-diff";
import superagent from 'superagent/lib/client'

import {ClearFix, Mixins, Paper} from 'material-ui';
import ComponentDoc from '../../component-doc';

const {StyleResizable} = Mixins;
import Code from 'paper-code';
import CodeExample from '../../code-example/code-example';
import CodeBlock from '../../code-example/code-block';

import tipCalculator from './tipCalculator.coffee';

function deepEqual(obj1, obj2) {
  var whereResult = _.where([obj1], obj2);
  return _.where([obj1], obj2).length == 1;
}

const TiPChart = React.createClass({

  getInitialState: function() {
    var cachedConfig = JSON.parse(localStorage.getItem('tip'));  // TODO: Update this to be a hash of 'tip' + this.state.userConfig
    if (! cachedConfig) {
      cachedConfig = {};
    };
    return {
      config: cachedConfig
    };
  },

  componentDidMount: function() {
    var cachedConfig;

    if (this.isMounted()) {
      cachedConfig = JSON.parse(localStorage.getItem('tip'));  // TODO: Use the hash
      if (! cachedConfig) cachedConfig = {};
      if (! deepEqual(cachedConfig, this.state.config)) {
        this.setState({config: cachedConfig});
      };
    }

    let lumenizeCalculatorConfig = {
      "config": {
        "query": {"Priority": 1},
        "stateFilter": {"State": {"$in": ["In Progress", "Accepted"]}},
        "granularity": "hour",
        "tz": "America/Chicago",
        "endBefore": "2015-12-14T03:36:12.662Z",
        "uniqueIDField": "_EntityID",
        "trackLastValueForTheseFields": ["_ValidTo", "Points"]
      }
    };

    //let chart = this.refs.chart.getChart();

    superagent.post("/time-in-state")
      .accept('json')
      .send(lumenizeCalculatorConfig)
      .end(function(err, response) {

      console.log('response: ', response.body);
      if (this.isMounted()) {



        var calculatorResults = tipCalculator({userConfig: this.state.userConfig, lumenizeCalculatorConfig}, response.body);
        var chartMax = 100;  // TODO: FIX THIS


        var scatterChartConfig = {

          chart: {
            type: 'bubble',
            plotBorderWidth: 1,
            zoomType: 'xy'
          },

          legend: {
            enabled: false
          },

          title: {
            text: 'Sugar and fat intake per country'
          },

          subtitle: {
            text: 'Source: <a href="http://www.euromonitor.com/">Euromonitor</a> and <a href="https://data.oecd.org/">OECD</a>'
          },

          xAxis: {
            gridLineWidth: 1,
            title: {
              text: 'Daily fat intake'
            },
            labels: {
              format: '{value} gr'
            },
            plotLines: [{
              color: 'black',
              dashStyle: 'dot',
              width: 2,
              value: 65,
              label: {
                rotation: 0,
                y: 15,
                style: {
                  fontStyle: 'italic'
                },
                text: 'Safe fat intake 65g/day'
              },
              zIndex: 3
            }]
          },

          yAxis: {
            startOnTick: false,
            endOnTick: false,
            title: {
              text: 'Daily sugar intake'
            },
            labels: {
              format: '{value} gr'
            },
            maxPadding: 0.2,
            plotLines: [{
              color: 'black',
              dashStyle: 'dot',
              width: 2,
              value: 50,
              label: {
                align: 'right',
                style: {
                  fontStyle: 'italic'
                },
                text: 'Safe sugar intake 50g/day',
                x: -10
              },
              zIndex: 3
            }]
          },

          tooltip: {
            useHTML: true,
            headerFormat: '<table>',
            pointFormat: '<tr><th colspan="2"><h3>{point.country}</h3></th></tr>' +
            '<tr><th>Fat intake:</th><td>{point.x}g</td></tr>' +
            '<tr><th>Sugar intake:</th><td>{point.y}g</td></tr>' +
            '<tr><th>Obesity (adults):</th><td>{point.z}%</td></tr>',
            footerFormat: '</table>',
            followPointer: true
          },

          plotOptions: {
            series: {
              dataLabels: {
                enabled: true,
                format: '{point.name}'
              }
            }
          },

          series: [{
            data: [
              { x: 95, y: 95, z: 13.8, name: 'BE', country: 'Belgium' },
              { x: 86.5, y: 102.9, z: 14.7, name: 'DE', country: 'Germany' },
              { x: 80.8, y: 91.5, z: 15.8, name: 'FI', country: 'Finland' },
              { x: 80.4, y: 102.5, z: 12, name: 'NL', country: 'Netherlands' },
              { x: 80.3, y: 86.1, z: 11.8, name: 'SE', country: 'Sweden' },
              { x: 78.4, y: 70.1, z: 16.6, name: 'ES', country: 'Spain' },
              { x: 74.2, y: 68.5, z: 14.5, name: 'FR', country: 'France' },
              { x: 73.5, y: 83.1, z: 10, name: 'NO', country: 'Norway' },
              { x: 71, y: 93.2, z: 24.7, name: 'UK', country: 'United Kingdom' },
              { x: 69.2, y: 57.6, z: 10.4, name: 'IT', country: 'Italy' },
              { x: 68.6, y: 20, z: 16, name: 'RU', country: 'Russia' },
              { x: 65.5, y: 126.4, z: 35.3, name: 'US', country: 'United States' },
              { x: 65.4, y: 50.8, z: 28.5, name: 'HU', country: 'Hungary' },
              { x: 63.4, y: 51.8, z: 15.4, name: 'PT', country: 'Portugal' },
              { x: 64, y: 82.9, z: 31.3, name: 'NZ', country: 'New Zealand' }
            ]
          }]

        };

        if (deepEqual({a:1}, {b:2})) console.log('is equal', deepEqual({a:1}, {b:2}));
        if (! deepEqual(cachedConfig, scatterChartConfig)) {
          localStorage.setItem('tip', JSON.stringify(scatterChartConfig));  // TODO: Use hash
          this.setState({
            config: scatterChartConfig
          });
        };
      }
    }.bind(this));
  },

  render() {
    return (
      <div>
        <ReactHighcharts width="66%" config={this.state.config} ref="chart"></ReactHighcharts>
      </div>
    );
  }
})

const TiPPage = React.createClass({

  mixins: [StyleResizable],

  getStyles() {
    let styles = {
      root: {
        height: '100px',
        width: '100px',
        margin: '0 auto',
        marginBottom: '64px',
        textAlign: 'center',
      },
      group: {
        float: 'left',
        width: '100%',
      },
      p: {
        lineHeight: '80px',
        height: '100%',
      },
    };

    if (this.isDeviceSize(StyleResizable.statics.Sizes.MEDIUM)) {
      styles.group.width = '33%';
    }

    return styles;
  },


  // TODO: Set userConfig from the UI filter settings

  render() {

    let groupStyle = this.getStyles().group;

    return (
      <Paper style = {{marginBottom: '22px'}}>
        <TiPChart userConfig={this.state.userConfig}/>
      </Paper>
    );
  },
});

export default TiPPage;
