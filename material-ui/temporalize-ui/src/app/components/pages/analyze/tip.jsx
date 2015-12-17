import React from 'react';
import Highcharts from 'highcharts-release/highcharts.src.js';
import ReactHighcharts from 'react-highcharts/bundle/highcharts';
import 'highcharts-exporting';
import _ from 'lodash';
import superagent from 'superagent/lib/client'

import {ClearFix, Mixins, Paper} from 'material-ui';
import ComponentDoc from '../../component-doc';

const {StyleResizable} = Mixins;
import Code from 'paper-code';
import CodeExample from '../../code-example/code-example';
import CodeBlock from '../../code-example/code-block';

const TiPChart = React.createClass({

  getInitialState: function() {
    return {
      config: {
        xAxis: {
          categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        },
        series: [{
          data: []
        }],
        credits: {
          enabled: false
        },
        title: {text: "Junk"}
      }
    };
  },

  componentDidMount: function() {
    let chart = this.refs.chart.getChart();
    let timeSeriesConfig = {
      "username": "larry@maccherone.com",
      "password": "BCltsn3^LlMF",
      "query": {"Priority": 1},
      "stateFilter": {"State": {"$in": ["In Progress", "Accepted"]}},
      "granularity": "hour",
        "tz": "America/Chicago",
        "endBefore": "2015-12-14T03:36:12.662Z",
        "uniqueIDField": "_EntityID",
        "trackLastValueForTheseFields": ["_ValidTo", "Points"]
    };
    superagent.post("http://temporalize.azurewebsites.net/time-in-state")
      .auth('larry@maccherone.com', "BCltsn3^LlMF")
      .end(function(err, response) {
      if (this.isMounted()) {
        console.log(response.body);
        var newConfig = _.cloneDeep(this.state.config);
        newConfig.xAxis.categories[3] = "Mystery Month";
        newConfig.series[0].data = [29.9, 71.5, 106.4, 129.2, 144.0, 176.0, 135.6, 148.5, 216.4, 194.1, 95.6, 54.4];
        this.setState({
          config: newConfig
        });
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



  render() {

    let groupStyle = this.getStyles().group;

    return (
      <Paper style = {{marginBottom: '22px'}}>
        <TiPChart />
      </Paper>
    );
  },
});

export default TiPPage;
