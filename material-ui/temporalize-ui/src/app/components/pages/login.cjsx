React = require('react')

_ = require('lodash')
superagent = require('superagent/lib/client')

{Styles} = require('material-ui')
# {StyleResizable, StylePropable} = Mixins  # I think this is safe to remove
{Spacing, Colors, Typography} = Styles

FullWidthSection = require('../full-width-section')

module.exports = React.createClass(

  # mixins: [StyleResizable]  # I think it's safe to not have this here

  render: () ->

    styles =
      spacer:
        paddingTop: Spacing.desktopKeylineIncrement
      root:
        backgroundColor: Colors.grey200
      content:
        maxWidth: 700
        padding: 0
        margin: '0 auto'
        fontWeight: Typography.fontWeightLight
        fontSize: 20
        lineHeight: '28px'
        paddingTop: 19
        marginBottom: 13
        letterSpacing: 0
        color: Typography.textDarkBlack

    return (
      <div style={styles.spacer}>
        <FullWidthSection
          style={styles.root}
          useContent={true}
          contentStyle={styles.content}
          contentType="p"
          className="login">
          Login
        </FullWidthSection>
      </div>
    )
)
