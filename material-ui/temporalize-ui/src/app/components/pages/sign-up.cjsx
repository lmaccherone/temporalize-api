React = require('react')

_ = require('lodash')
zxcvbn = require('zxcvbn')  # TODO: Consider loading this from the web. It adds several hundred KB to the app.js

{Avatar, Styles, TextField, FlatButton, RaisedButton, Mixins
  Card, CardHeader, CardText, CardActions} = require('material-ui')
{StylePropable} = Mixins  # I think this is safe to have removed StyleResizable, but not sure
{Spacing, Colors, Typography} = Styles
ThemeManager = Styles.ThemeManager
DefaultRawTheme = Styles.LightRawTheme

FullWidthSection = require('../full-width-section')
request = require('../../api-request')
history = require('../../history')
JSONStorage = require('../../JSONStorage')

validEmailRegex = /.+@.+\..+/i

module.exports = React.createClass(

  mixins: [StylePropable]  # I think it's safe to not StyleResizable here, but not sure what that does

  getInitialState: () ->
    muiTheme = ThemeManager.getMuiTheme(DefaultRawTheme)
    return {
      message: ''
      messageColor: DefaultRawTheme.palette.primary1Color
      buttonsDisabled: true
      muiTheme
      emailErrorText: ''
      passwordErrorText: ''
      reenterPasswordErrorText: ''
      organizationErrorText: ''
    }

  componentDidMount: () ->
    if @isMounted()
      @validateInput()

  handleSignUp: (event) ->
    if @validateInput()
      @setState({buttonsDisabled: true})
      username = @refs.username.getValue()
      password = @refs.password.getValue()
      organizationName = @refs.organizationName.getValue()
      request('/create-tenant', {tenant: {name: organizationName}, adminUser: {username, password}}, (err, response) =>
        if err?
          @setState({
            message: err.response.body
          })
        else
          request('/login', {username, password}, (err, response) =>
            if err?
              @setState({
                message: err.response.body
              })
            else
              @setState({
                message: "Login successful"
              })
              # Save the session
              JSONStorage.setItem('session', response.body)
              history.replace('/config/organization')
          )
      )

  validateEmail: () ->
    username = @refs.username.getValue()
    if username.length < 1
      @setState({
        emailErrorText: 'Required'
      })
      return false
    if not validEmailRegex.test(username)
      @setState({
        emailErrorText: 'Invalid email'
      })
      return false
    # Everything OK
    @setState({emailErrorText: ''})
    return true

  validatePassword: () ->
    password = @refs.password.getValue()
    if password.length < 1
      @setState({
        passwordErrorText: 'Required'
      })
      return false
    passwordStrength = zxcvbn(password)
    if passwordStrength.score < 2
      if passwordStrength.feedback.warning.length > 0
        text = passwordStrength.feedback.warning
      else
        text = 'Password too weak'
      @setState({
        passwordErrorText: text
      })
      return false
    # Everything OK
    @setState({passwordErrorText: ''})
    return true

  validateReenterPassword: () ->
    password = @refs.password.getValue()
    reenterPassword = @refs.reenterPassword.getValue()
    if password isnt reenterPassword
      @setState({
        reenterPasswordErrorText: "Passwords don't match"
      })
      return false
    # Everything OK
    @setState({reenterPasswordErrorText: ''})
    return true

  validateOrganization: () ->
    organizationName = @refs.organizationName.getValue()
    if organizationName.length < 1
      @setState({
        organizationErrorText: "Required"
      })
      return false
    # Everything OK
    @setState({organizationErrorText: ''})
    return true

  validateInput: () ->
    buttonsDisabled = false
    if ! @validateEmail()
      buttonsDisabled = true
    if ! @validatePassword()
      buttonsDisabled = true
    if ! @validateReenterPassword()
      buttonsDisabled = true
    if ! @validateOrganization()
      buttonsDisabled = true
    @setState({buttonsDisabled})
    return ! buttonsDisabled

  childContextTypes:
    muiTheme: React.PropTypes.object

  getChildContext: () ->
    return {
      muiTheme: @state.muiTheme
    }

  getStyles: () ->
    styles =
      root:
        backgroundColor: Colors.grey200
      content:
        width: 290
        padding: 0
        margin: '0 auto'
        fontWeight: Typography.fontWeightLight
        fontSize: 20
        lineHeight: '28px'
        paddingTop: 19
        marginBottom: 13
        letterSpacing: 0
        color: Typography.textDarkBlack
      actions:
        margin: 10

    return styles

  render: () ->

    styles = @getStyles()

    return (
      <FullWidthSection
        style={styles.root}
        useContent={true}
        contentStyle={styles.content}>
        <Card initiallyExpanded={true} expandable={false}>
          <CardHeader
            subtitleStyle={color: DefaultRawTheme.palette.accent1Color}
            actAsExpander={true}
            title="Sign up"
            subtitle={@state.message}
            showExpandableButton={false}>
          </CardHeader>
          <CardText expandable={false}>
            <TextField
              ref='username'
              hintText="someone@somewhere.com"
              floatingLabelText="Email"
              errorText={@state.emailErrorText}
              onChange={@validateInput}
              onEnterKeyDown={@handleSignUp}
            />
            <TextField
              ref='password'
              hintText="Pasword"
              floatingLabelText="Password"
              errorText={@state.passwordErrorText}
              type="password"
              onChange={@validateInput}
              onEnterKeyDown={@handleSignUp}
            />
            <TextField
              ref='reenterPassword'
              hintText="Reenter password"
              floatingLabelText="Reenter password"
              errorText={@state.reenterPasswordErrorText}
              type="password"
              onChange={@validateInput}
              onEnterKeyDown={@handleSignUp}
            />
            <TextField
              ref='organizationName'
              hintText="Organization name"
              floatingLabelText="Organization name"
              errorText={@state.organizationErrorText}
              onChange={@validateInput}
              onEnterKeyDown={@handleSignUp}
            />
          </CardText>
        </Card>
        <RaisedButton
          style={styles.actions}
          label="Sign up"
          primary={true}
          linkButton={true}
          onTouchTap={@handleSignUp}
          disabled={@state.buttonsDisabled}
        />
      </FullWidthSection>
    )
)
