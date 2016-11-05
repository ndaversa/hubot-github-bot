_ = require "underscore"

class GenericAdapter
  @GITHUB_NOTIFICATIONS_DISABLED: "github-notifications-disabled"
  @GITHUB_DM_COUNTS: "github-dm-counts"

  constructor: (@robot) ->
    @disabledUsers = null
    @dmCounts = null

    @robot.brain.once "loaded", =>
      @disabledUsers = @robot.brain.get(GenericAdapter.GITHUB_NOTIFICATIONS_DISABLED) or []
      @dmCounts = @robot.brain.get(GenericAdapter.GITHUB_DM_COUNTS) or {}

  disableNotificationsFor: (user) ->
    @robot.logger.info "Disabling Github notifications for #{user.name}"
    @disabledUsers.push user.id
    @robot.brain.set GenericAdapter.GITHUB_NOTIFICATIONS_DISABLED, _(@disabledUsers).unique()
    @robot.brain.save()

  enableNotificationsFor: (user) ->
    @robot.logger.info "Enabling Github notifications for #{user.name}"
    @disabledUsers = _(@disabledUsers).without user.id
    @robot.brain.set GenericAdapter.GITHUB_NOTIFICATIONS_DISABLED, @disabledUsers
    @robot.brain.save()

  incrementDMCountFor: (user) ->
    return unless @dmCounts?
    return unless user?.id?

    @dmCounts[user.id] ||= 0
    @dmCounts[user.id]++
    @robot.brain.set GenericAdapter.GITHUB_DM_COUNTS, @dmCounts
    @robot.brain.save()

  getDMCountFor: (user) ->
    return 0 unless @dmCounts?
    return 0 unless user?.id?
    @dmCounts[user.id] ||= 0
    return @dmCounts[user.id]

  send: (context, message) ->
    if _(message).isString()
      payload = message
    else if message.text or message.attachments
      payload = ""

      if message.text
        payload += "#{message.text}\n"

      if message.attachments
        for attachment in message.attachments
          payload += "#{attachment.fallback}\n"
    else
      return @robot.logger.error "Unable to find a message to send", message

    @robot.send room: context.message.room, payload

  dm: (users, message) ->
    users = [ users ] unless _(users).isArray()
    for user in users when user
      if _(@disabledUsers).contains user.id
        @robot.logger.debug "Github Notification surpressed for #{user.name}"
      else
        if message.author? and user.name is message.author.name
          @robot.logger.debug "Github Notification surpressed for #{user.name} because it would be a self-notification"
          continue
        message.text += "\n#{message.footer}" if message.text and message.footer and @getDMCountFor(user) < 3
        @send message: room: user.id, message
        @incrementDMCountFor user

  getPermalink: (msg) -> ""

module.exports = GenericAdapter
