import React from 'react';
import Highcharts from 'highcharts-release/highcharts.src.js';
import ReactHighcharts from 'react-highcharts/bundle/highcharts';
import 'highcharts-exporting';

import {ClearFix, Mixins, Paper} from 'material-ui';
import ComponentDoc from '../../component-doc';

const {StyleResizable} = Mixins;
import Code from 'paper-code';
import CodeExample from '../../code-example/code-example';
import CodeBlock from '../../code-example/code-block';

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

    let componentInfo = [
      {
        name: 'Props',
        infoArray: [
          {
            name: 'circle',
            type: 'bool',
            header: 'default: false',
            desc: 'Set to true to generate a circlular paper container.',
          },
          {
            name: 'rounded',
            type: 'bool',
            header: 'default: true',
            desc: 'By default, the paper container will have a border radius. ' +
              'Set this to false to generate a container with sharp corners.',
          },
          {
            name: 'style',
            type: 'object',
            header: 'optional',
            desc: 'Override the inline-styles of Paper\'s root element.',
          },
          {
            name: 'zDepth',
            type: 'oneOf [0,1,2,3,4,5]',
            header: 'default: 1',
            desc: 'This number represents the zDepth of the paper shadow.',
          },
          {
            name: 'transitionEnabled',
            type: 'bool',
            header: 'default: true',
            desc: 'Set to false to disable CSS transitions for the paper element.',
          },
        ],
      },
    ];

    let groupStyle = this.getStyles().group;

    var config = {
      xAxis: {
        categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
      },
      series: [{
        data: [29.9, 71.5, 106.4, 129.2, 144.0, 176.0, 135.6, 148.5, 216.4, 194.1, 95.6, 54.4]
      }],
      credits: {
        enabled: false
      }
    };

    return (
      <Paper style = {{marginBottom: '22px'}}>
        <ReactHighcharts config = {config} ref="chart"></ReactHighcharts>
      </Paper>
    );
  },
});

export default TiPPage;
