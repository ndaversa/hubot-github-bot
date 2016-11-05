_ = require "underscore"

GenericAdapter = require "./generic"

class Slack extends GenericAdapter
  constructor: (@robot) ->
    super @robot

  send: (context, message) ->
    payload = {}
    if _(message).isString()
      payload.text = message
    else
      payload = _(payload).extend message
    @robot.adapter.send room: context.message.room, payload

module.exports = Slack
