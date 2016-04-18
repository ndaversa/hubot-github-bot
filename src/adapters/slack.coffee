_ = require "underscore"

GenericAdapter = require "./generic"

class Slack extends GenericAdapter
  constructor: (@robot) ->
    super @robot

  send: (context, message) ->
    payload = channel: context.message.room
    if _(message).isString()
      payload.text = message
    else
      payload = _(payload).extend message
    rc = @robot.adapter.customMessage payload

    # Could not find existing conversation
    # so client bails on sending see issue: https://github.com/slackhq/hubot-slack/issues/256
    # detect the bail by checking the response and attempt
    # a fallback using adapter.send
    if rc is undefined
      text = payload.text
      text += "\n#{a.fallback}" for a in payload.attachments
      @robot.adapter.send context.message, text

module.exports = Slack
