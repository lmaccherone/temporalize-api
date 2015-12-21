React = require('react')

_ = require('lodash')

{NavigationCancel, ActionCheckCircle} = require('material-ui/lib/svg-icons')
{Avatar, Styles, TextField, FlatButton, FontIcon, Mixins} = require('material-ui')
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
      message: 'Sign up'
      messageColor: DefaultRawTheme.palette.primary1Color
      buttonsDisabled: false
      passwordsMatchColor: Colors.red200
      passwordsMatchIcon: 'nothing'
      muiTheme
    }

  _passwordsMatch: () ->
    password = @refs.password.getValue()
    reenterPassword = @refs.reenterPassword.getValue()
    return password is reenterPassword

  handleSignUp: (event) ->
    if @_passwordsMatch()
      @state.buttonsDisabled = true
      username = @refs.username.getValue()
      password = @refs.password.getValue()
      @forceUpdate()  # Seems to be needed to trigger disabling of button
      request('/upsert-tenant', {newAdminUser: {username, password}}, (err, response) =>
        @setState({buttonsDisabled: false})
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

  goToLogin: (event) ->
    history.push('/login')

  checkPasswordsMatch: (event) ->
    password = @refs.password.getValue()
    reenterPassword = @refs.reenterPassword.getValue()
    if reenterPassword.length > 1
      if @_passwordsMatch()
        @setState({
          passwordsMatchIcon: ActionCheckCircle
          passwordsMatchColor: Colors.green200
        })
      else
        @setState({
          passwordsMatchIcon: NavigationCancel
          passwordsMatchColor: Colors.red200
        })
    else
      @setState({passwordsMatchIcon: 'nothing'})

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
            <FlatButton
              style={left:10}
              label="Sign up"
              primary={true}
              linkButton={true}
              onTouchTap={@handleSignUp}
              disabled={@state.buttonsDisabled}
            />
          </div>
          <div>
            <TextField
              ref='password'
              hintText="Password"
              floatingLabelText="Password"
              type="password"
              onChange={@checkPasswordsMatch}
            />
            <FlatButton
              style={left:10}
              label="Login"
              primary={false}
              onTouchTap={@goToLogin}
              disabled={@state.buttonsDisabled}
            />
          </div>
          <div>
            <TextField
              ref='reenterPassword'
              hintText="Reenter password"
              floatingLabelText="Reenter password"
              type="password"
              onChange={@checkPasswordsMatch}
            />
            <Avatar
              icon={<@state.passwordsMatchIcon />}
              color={@state.passwordsMatchColor}
              backgroundColor={"#EEEEEE"}>
            </Avatar>
          </div>
        </FullWidthSection>
      </div>
    )
)
