import React from 'react';
import PageWithNav from './page-with-nav';

export default class Analyze extends React.Component {

  render() {
    let menuItems = [
      {route: '/analyze/tip', text: 'TiP'}
    ];

    return (
      <PageWithNav location={this.props.location} menuItems={menuItems}>{this.props.children}</PageWithNav>
    );
  }

}

Analyze.propTypes = {
  children: React.PropTypes.node,
  location: React.PropTypes.object,
};
