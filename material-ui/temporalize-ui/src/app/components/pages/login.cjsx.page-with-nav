React = require('react')

PageWithNav = require('./page-with-nav')

Analyze = React.createClass(

  render: () ->
    menuItems = [
      {route: '/analyze/tip', text: 'TiP'}
    ]

    return (
      <PageWithNav location={@props.location} menuItems={menuItems}>{@props.children}</PageWithNav>
    )

)


Analyze.propTypes =
  children: React.PropTypes.node
  location: React.PropTypes.object


module.exports = Analyze
