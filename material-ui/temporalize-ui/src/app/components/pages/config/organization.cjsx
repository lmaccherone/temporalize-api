React = require('react')

_ = require('lodash')

{Mixins, Avatar, RaisedButton, TextField, Styles
  Card, CardHeader, CardText, CardActions} = require('material-ui')
{StyleResizable} = Mixins
{Spacing, Colors, Typography} = Styles
DefaultRawTheme = Styles.LightRawTheme

request = require('../../../api-request')
JSONStorage = require('../../../JSONStorage')

module.exports = React.createClass(

  mixins: [StyleResizable]

  componentDidMount: () ->
    if @isMounted()
      @validateInput()

  getStyles: () ->
    styles =
      actions:
        margin: 10

    return styles

  getInitialState: () ->
    return {
      name: ''
      nameErrorText: ''
      pageErrorText: 'Something'
    }

  validateName: () ->
    name = @refs.name.getValue()
    if name.length < 1
      @setState({nameErrorText: "Required"})
      return false
    @setState({nameErrorText: ''})
    return true

  validateInput: () ->
    buttonsDisabled = false
    if ! @validateName()
      buttonsDisabled = true
    @setState({buttonsDisabled})
    return ! buttonsDisabled

  handleSave: (event) ->
    if @validateInput()
      @setState({buttonsDisabled: true})
      name = @refs.name.getValue()
      request('/upsert-tenant', {name}, (err, response) =>
        if err?
          @setState({pageErrorText: err.response.body})
        else
          @setState({buttonsDisabled: false})
      )

  render: () ->

    styles = @getStyles()

    return (
      <div>
        <Card initiallyExpanded={true}>
          <CardHeader
            subtitleStyle={color: DefaultRawTheme.palette.accent1Color}
            actAsExpander={true}
            title="Organization"
            subtitle={@state.pageErrorText}
            showExpandableButton={true}>
          </CardHeader>
          <CardText expandable={true}>
            <TextField
              ref='name'
              hintText="Acme, Inc."
              floatingLabelText="Name"
              onChange={@validateInput}
              onEnterKeyDown={@handleSave}
              errorText={@state.nameErrorText}
              errorStyle={color: DefaultRawTheme.palette.accent1Color}
            />
          </CardText>
        </Card>
        <div>
          <RaisedButton
            style={styles.actions}
            label="Save"
            primary={true}
            onTouchTap={@handleSave}
            disabled={@state.buttonsDisabled}/>
          <RaisedButton style={styles.actions} label="Cancel" primary={false}/>
        </div>
      </div>

    )
)
