React = require('react')

_ = require('lodash')

{Styles, TextField, RaisedButton, FlatButton, Mixins,
  Card, CardHeader, CardText, CardActions} = require('material-ui')
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
      message: ""
      buttonsDisabled: false
      muiTheme
    }

  handleLogin: (event) ->
    @setState({buttonsDisabled: true})
    username = @refs.username.getValue()
    password = @refs.password.getValue()
    request('/login', {username, password}, (err, response) =>
      @setState({buttonsDisabled: false})
      if err?
        @setState({
          message: err.response.body
        })
      else
        @setState({
          message: "Login successful"
        })
        # Save the session
        session = response.body
        if session? and session.user? and session.id?
          JSONStorage.setItem('session', response.body)
          nextPathname = JSONStorage.getItem('nextPathname')
          if nextPathname?
            history.replace(nextPathname)
          else
            history.replace('/')
    )

  goToSignup: (event) ->
    history.push('/sign-up')

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
        color: DefaultRawTheme.palette.accent1Color

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
            title="Login"
            subtitle={@state.message}
            showExpandableButton={false}>
          </CardHeader>
          <CardText expandable={false}>
            <TextField
              ref='username'
              hintText="someone@somewhere.com"
              floatingLabelText="Email"
            />
            <TextField
              ref='password'
              hintText="Password"
              floatingLabelText="Password"
              type="password"
              onEnterKeyDown={@handleLogin}
            />
          </CardText>
        </Card>
        <RaisedButton
          style={styles.actions}
          label="Login"
          primary={true}
          onTouchTap={@handleLogin}
          disabled={@state.buttonsDisabled}
        />
        <a style={styles.actions} href='#/sign-up'>Sign up</a>
      </FullWidthSection>
    )
)
