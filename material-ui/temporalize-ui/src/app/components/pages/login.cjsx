React = require('react')

_ = require('lodash')
superagent = require('superagent/lib/client')

{Styles, TextField, FlatButton} = require('material-ui')
# {StyleResizable, StylePropable} = Mixins  # I think this is safe to remove
{Spacing, Colors, Typography} = Styles

FullWidthSection = require('../full-width-section')

module.exports = React.createClass(

  # mixins: [StyleResizable]  # I think it's safe to not have this here

  handleLogin: (event) ->
    username = @refs.username.getValue()
    password = @refs.password.getValue()

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
          className="login">
          <div>
            <TextField
              ref='username'
              hintText="someone@somewhere.com"
              floatingLabelText="Email"
            />
          </div>
          <div>
            <TextField
              ref='password'
              hintText="Password"
              floatingLabelText="Password"
              type="password"
            />
            <FlatButton style={left:10} label="Login" primary={true} onTouchTap={@handleLogin} />
          </div>
        </FullWidthSection>
      </div>
    )
)
