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

import tipCalculator from './tipCalculator.coffee';

const TiPChart = React.createClass({

  getInitialState: function() {
    return {config: {}};
  },

  componentDidMount: function() {
    var userConfig = {
      subTitle: 'Stories In-Progress to Accepted',
      debug: true,
      trace: true,
      daysToShow: 120,
      // asOf: "2012-10-15",  // Optional. Only supply if want a specific time frame. Do not send in new Date().toISOString().

      scopeField: "_ProjectHierarchy",  // Supports Iteration, Release, Tags, Project, _ProjectHierarchy, _ItemHierarchy
      scopeValue: 'scope',

      statePredicate: {ScheduleState:{$lt:"Accepted", $gte:"In-Progress"}},
      currentStatePredicate: {ScheduleState:{$gte:"Accepted"}},
      type: 'HierarchicalRequirement',
      leafOnly: true,
      showTheseFieldsInToolTip: [ // Will automatically show ObjectID and Work Days In State
        'Name',
        {field: 'PlanEstimate', as: "Plan Estimate"}
      ],
      radiusField: {field: 'PlanEstimate', f: function(value){
        if (isNaN(value)) {
          return 5
        } else {
          return Math.pow(value, 0.6) + 5
        }
      }},
      workDayStartOn: {hour: 9},
      workDayEndBefore: {hour: 17},
      // deriveFieldsOnSnapshotsConfig:
      // holidays: (unless we pull them from some data model in Rally)
      // workDays: (if you want to override the default pulling from WorkspaceConfiguration)
    };

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



        var calculatorResults = tipCalculator({userConfig, lumenizeCalculatorConfig}, response.body);
        var chartMax = 100;  // TODO: FIX THIS

        var scatterChartConfig = {
          config: {
            chart: {
              renderTo: 'scatter-container',
              defaultSeriesType: 'scatter',
              zoomType: 'x',
              marginTop: 80
            },
            legend: {
              enabled: true,
              floating: true,
              align: 'center',
              verticalAlign: 'top',
              y: 37
            },
            credits: {
              enabled: false
            },
            title: {
              text: 'Time In Process (TiP)'
            },
            subtitle: {
              text: userConfig.subTitle
            },
            xAxis: {
              startOnTick: false,
              tickmarkPlacement: 'on',
              title: {
                enabled: false
              },
              type: 'datetime',
              min: calculatorResults.startMilliseconds,
              max: calculatorResults.asOfMilliseconds
            },
            yAxis: [
              {
                title: {
                  text: 'Time In Process (Work Days)'
                },
                opposite: false,
                endOnTick: false,
                //tickInterval: bucketSize,
                //labels: {
                //  formatter: function() {
                //    if (this.value !== 0) {
                //      if (this.value == chartMax) {
                //        if (clipped) {
                //          return '' + valueMax + '*';
                //        } else {
                //          return chartMax;
                //        }
                //      } else {
                //        return this.value;
                //      }
                //    }
                //  }
                //},
                min: 0,
                max: chartMax
              },
              {
                title: {
                  text: null
                },
                opposite: true,
                // endOnTick: true,
                tickInterval: 1,
                //labels: {
                //  formatter: function() {
                //    if (this.value !== 0) {
                //      return Highcharts.numberFormat(buckets[this.value - 1].percentile * 100, 1) + "%";
                //    } else {
                //      return "0.0%";
                //    }
                //  }
                //},
                min: 0,
                //max: buckets.length
              }

            ],
            //tooltip: {
              //formatter: function() {
              //  var point = this.point;
              //  tooltip = 'ObjectID: ' + point.ObjectID + '<br />';  // !TODO: Upgrade to link to revisions page in Rally
              //  tooltip += this.series.name + ': <b>' + Highcharts.numberFormat(point.days, 1) + '</b> work days';
              //  var t, _i, _len, _ref, f, field, as;
              //  _ref = userConfig.showTheseFieldsInToolTip;
              //  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              //    t = _ref[_i];
              //    if (typeof t === 'string') {
              //      field = t;
              //      f = function(value) {
              //        return value;
              //      };
              //      as = t;
              //    } else {
              //      field = t.field;
              //      if (t.f != null) {
              //        f = t.f;
              //      } else {
              //        f = function(value) {
              //          return value;
              //        };
              //      }
              //      if (t.as != null) {
              //        as = t.as;
              //      } else {
              //        as = t.field;
              //      }
              //    }
              //    tooltip += '<br />' + as + ': ' + f(point[field + "_lastValue"]);
              //  }
              //  return tooltip;
              //}
            //},
            plotOptions: {
              scatter: {
                marker: {
                  states: {
                    hover: {
                      enabled: false
                    }
                  }
                }
              },
              series: {
                //events: {
                //  legendItemClick: function(event) {
                //    if (this.index == 0) {
                //      if (!this.visible) {
                //        this.chart.xAxis[0].setExtremes(calculatorResults.startMilliseconds, calculatorResults.asOfMilliseconds, false);
                //      } else {
                //        this.chart.xAxis[0].setExtremes(calculatorResults.asOfMilliseconds - 24 * 60 * 60 * 1000, calculatorResults.asOfMilliseconds, false);
                //      };
                //      this.chart.redraw();
                //    };
                //    return true;
                //  }
                //}
              }
            },
            series: calculatorResults.series
          }
        };

        scatterChartConfig = {
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

        console.log('got to just before setting state. config', scatterChartConfig);
        this.setState({
          config: scatterChartConfig
        });

        console.log('forcing update');
        this.forceUpdate();
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
