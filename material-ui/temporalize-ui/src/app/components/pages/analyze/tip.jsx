import React from 'react';
import Highcharts from 'highcharts-release/highcharts.src.js';
import ReactHighcharts from 'react-highcharts/bundle/highcharts';
import 'highcharts-exporting';
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
          subtitle: {
            text: 'Subtitle'
          },

          xAxis: {
            categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
          },

          series: [{
            data: [29.9, 71.5, 106.4, 129.2, 144.0, 176.0, 135.6, 148.5, 216.4, 194.1, 95.6, 54.4]
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
