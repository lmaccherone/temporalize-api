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

  # validateEverything: () ->
  #   unless validateName()
  #     return false

  validateName: () ->
    name = @refs.name.getValue()
    if name.length < 1
      newErrorText = "required"
      result = false
    else
      newErrorText = ""
      result = true
    @setState({nameErrorText: newErrorText})
    return result

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
              onChange={@validateName}
              onEnterKeyDown={@handleUpdate}
              errorText={@state.nameErrorText}
            />
          </CardText>
        </Card>
        <div>
          <RaisedButton style={styles.actions} label="Update" primary={true}/>
          <RaisedButton style={styles.actions} label="Cancel" primary={false}/>
        </div>
      </div>

    )
)
