React = require('react')

_ = require('lodash')
zxcvbn = require('zxcvbn')  # TODO: Consider loading this from the web. It adds several hundred KB to the app.js

{NavigationCancel, ActionCheckCircle} = require('material-ui/lib/svg-icons')
{Avatar, Styles, TextField, FlatButton, RaisedButton, FontIcon, Mixins} = require('material-ui')
{StylePropable} = Mixins  # I think this is safe to have removed StyleResizable, but not sure
{Spacing, Colors, Typography} = Styles
ThemeManager = Styles.ThemeManager
DefaultRawTheme = Styles.LightRawTheme

FullWidthSection = require('../full-width-section')
request = require('../../api-request')
history = require('../../history')
JSONStorage = require('../../JSONStorage')

validPasswordRegex = /.+@.+\..+/i

module.exports = React.createClass(

  mixins: [StylePropable]  # I think it's safe to not StyleResizable here, but not sure what that does

  getInitialState: () ->
    muiTheme = ThemeManager.getMuiTheme(DefaultRawTheme)
    return {
      message: 'Sign up'
      messageColor: DefaultRawTheme.palette.primary1Color
      buttonsDisabled: true
      validationIcon: 'nothing'
      muiTheme
    }

  componentDidMount: () ->
    if @isMounted()
      @validateInput()

  handleSignUp: (event) ->
    if @validateInput()
      @setState({buttonsDisabled: true})
      username = @refs.username.getValue()
      password = @refs.password.getValue()
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

  validateInput: (event) ->
    username = @refs.username.getValue()
    if username.length < 1
      @setState({
        validationIcon: NavigationCancel
        message: 'Missing email'
        messageColor: DefaultRawTheme.palette.accent1Color
        buttonsDisabled: true
      })
      return false
    if not validPasswordRegex.test(username)
      @setState({
        validationIcon: NavigationCancel
        message: 'Invalid email'
        messageColor: DefaultRawTheme.palette.accent1Color
        buttonsDisabled: true
      })
      return false

    password = @refs.password.getValue()
    if password.length < 1
      @setState({
        validationIcon: NavigationCancel
        message: 'Missing password'
        messageColor: DefaultRawTheme.palette.accent1Color
        buttonsDisabled: true
      })
      return false
    passwordStrength = zxcvbn(password)
    if passwordStrength.score < 2
      if passwordStrength.feedback.warning.length > 0
        message = passwordStrength.feedback.warning
      else
        message = 'Password too weak'
      @setState({
        validationIcon: NavigationCancel
        message: message
        messageColor: DefaultRawTheme.palette.accent1Color
        buttonsDisabled: true
      })
      return false

    reenterPassword = @refs.reenterPassword.getValue()
    if password isnt reenterPassword
      @setState({
        validationIcon: NavigationCancel
        message: "Passwords don't match"
        messageColor: DefaultRawTheme.palette.accent1Color
        buttonsDisabled: true
      })
      return false

    # Everthing above passed so must be OK
    @setState({
      validationIcon: ActionCheckCircle
      message: 'Sign up'
      messageColor: DefaultRawTheme.palette.primary1Color
      buttonsDisabled: false
    })
    return true

  # checkPasswords: (event) ->
  #   password = @refs.password.getValue()
  #   reenterPassword = @refs.reenterPassword.getValue()
  #   if reenterPassword.length > 1
  #     if @_passwordsMatch()
  #       @setState({
  #         validationIcon: ActionCheckCircle
  #         validationColor: Colors.green200
  #       })
  #     else
  #       @setState({
  #         validationIcon: NavigationCancel
  #         validationColor: Colors.red200
  #       })
  #   else
  #     @setState({validationIcon: 'nothing'})

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
          contentStyle={styles.content}>
          <div style={color: @state.messageColor}>
            {@state.message}
          </div>
          <div>
            <TextField
              ref='username'
              hintText="someone@somewhere.com"
              floatingLabelText="Email"
              onChange={@validateInput}
              onEnterKeyDown={@handleSignUp}
            />
            &nbsp;
            <RaisedButton
              style={left:10}
              label="Sign up"
              primary={true}
              linkButton={true}
              onTouchTap={@handleSignUp}
              disabled={@state.buttonsDisabled}
            />
            &nbsp;
            <Avatar
              icon={<@state.validationIcon />}
              color={@state.messageColor}
              backgroundColor={"#EEEEEE"}>
            </Avatar>
          </div>
          <div>
            <TextField
              ref='password'
              hintText="Pasword"
              floatingLabelText="Password"
              type="password"
              onChange={@validateInput}
              onEnterKeyDown={@handleSignUp}
            />
          </div>
          <div>
            <TextField
              ref='reenterPassword'
              hintText="Reenter password"
              floatingLabelText="Reenter password"
              type="password"
              onChange={@validateInput}
              onEnterKeyDown={@handleSignUp}
            />
          </div>
        </FullWidthSection>
      </div>
    )
)
