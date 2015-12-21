React = require('react')

_ = require('lodash')

{Styles, TextField, FlatButton, Mixins} = require('material-ui')
{StylePropable} = Mixins  # I think this is safe to have removed StyleResizable, but not sure
{Spacing, Colors, Typography} = Styles
ThemeManager = Styles.ThemeManager
DefaultRawTheme = Styles.LightRawTheme

FullWidthSection = require('../full-width-section')
request = require('../../api-request')
history = require('../../history')
JSONStorage = require('../../JSONStorage')

module.exports = React.createClass(

  mixins: [StylePropable]  # I think it's safe to not StyleResizable here, but not sure what that does

  getInitialState: () ->
    muiTheme = ThemeManager.getMuiTheme(DefaultRawTheme)
    return {
      message: 'Login'
      messageColor: DefaultRawTheme.palette.primary1Color
      loginButtonDisabled: false
      muiTheme
    }

  handleLogin: (event) ->
    username = @refs.username.getValue()
    password = @refs.password.getValue()
    @state.loginButtonDisabled = true
    @forceUpdate()  # Seems to be needed to trigger disabling of button
    request('/login', {username, password}, (err, response) =>
      @setState({loginButtonDisabled: false})
      if err?
        @setState({
          message: err.response.body
          messageColor: DefaultRawTheme.palette.accent1Color
        })
      else
        # Save the session
        JSONStorage.setItem('session', response.body)
        nextPathname = JSONStorage.getItem('nextPathname')
        if nextPathname?
          history.replace(nextPathname)
        else
          history.replace('/')
    )

  childContextTypes:
    muiTheme: React.PropTypes.object

  getChildContext: () ->
    return {
      muiTheme: @state.muiTheme
    }

  getStyles: () ->
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

    return styles

  render: () ->

    styles = @getStyles()

    return (
      <div style={styles.spacer}>
        <FullWidthSection
          style={styles.root}
          useContent={true}
          contentStyle={styles.content}
          className="login">
          <div style={color: @state.messageColor}>{@state.message}</div>
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
              onEnterKeyDown={@handleLogin}
            />
            <FlatButton style={left:10} label="Login" primary={true} onTouchTap={@handleLogin} disabled={@state.loginButtonDisabled}/>
          </div>
        </FullWidthSection>
      </div>
    )
)