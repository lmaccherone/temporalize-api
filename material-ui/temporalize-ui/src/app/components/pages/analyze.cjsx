React = require('react')
PageWithNav = require('./page-with-nav')

module.exports = class Analyze extends React.Component

  render: () ->
    menuItems = [
      {route: '/analyze/tip', text: 'TiP'}
    ]

    session = localStorage.getItem('session')

    return (
      <PageWithNav location={@props.location} menuItems={menuItems}>{@props.children}</PageWithNav>
    )

Analyze.propTypes =
  children: React.PropTypes.node
  location: React.PropTypes.object
