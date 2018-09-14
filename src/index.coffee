# Description:
# A hubot script to list and recurrently remind you about open pull requests.
# Optionally receive direct messages when you are assigned to a pull
# request in your organization or for a specific repo or set of repos.
#
# Dependencies:
#  - coffeescript
#  - cron
#  - octokat
#  - moment
#  - underscore
#  - fuse.js
#
# Configuration:
#   HUBOT_GITHUB_TOKEN - Github Application Token
#   HUBOT_GITHUB_WEBHOOK_SECRET - Optional, if you are using webhooks and have a secret set this for additional security checks on payload delivery
#   HUBOT_GITHUB_URL - Set this value if you are using Github Enterprise   default: `https://api.github.com`
#   HUBOT_GITHUB_ORG - Github Organization Name (the one in the url)
#   HUBOT_GITHUB_REPOS_MAP (format: "{"web":["frontend","web"],"android":["android"],"ios":["ios"],"platform":["web"]}"
#
# Commands:
#   hubot github open [for <user>] - Shows a list of open pull requests for the repo of this room [optionally for a specific user]
#   hubot github remind hh:mm - I'll remind about open pull requests in this room at hh:mm every weekday.
#   hubot github list reminders - See all pull request reminders for this room.
#   hubot github reminders in every room - Be nosey and see when other rooms have their reminders set
#   hubot github delete hh:mm reminder - If you have a reminder at hh:mm, I'll delete it.
#   hubot github delete all reminders - Deletes all reminders for this room.
#
# Author:
#   ndaversa

_ = require 'underscore'
Adapters = require "./adapters"
Config = require "./config"
Github = require "./github"
Reminders = require "./reminders"
Utils = require "./utils"

class GithubBot

  constructor: (@robot) ->
    return new GithubBot @robot unless @ instanceof GithubBot
    Utils.robot = @robot
    @reminders = new Reminders @robot, "github-reminders", (name) ->
      room = Utils.getRoom message: room: name
      Github.PullRequests.openForRoom room
    @webhook = new Github.Webhook @robot
    switch @robot.adapterName
      when "slack"
        @adapter = new Adapters.Slack @robot
      else
        @adapter = new Adapters.Generic @robot

    @registerWebhookListeners()
    @registerEventListeners()
    @registerRobotResponses()

  send: (context, message) ->
    @adapter.send context, message

  registerWebhookListeners: ->
    disableDisclaimer = """
      If you wish to stop receiving notifications about github reply with:
      > github disable notifications
    """

    @robot.on "GithubPullRequestAssigned", (pr, sender) =>
      @robot.logger.debug "Sending PR assignment notice to #{pr.assignee.name}, sender is #{sender?.name}"
      @adapter.dm pr.assignee,
        text: """
          You have just been assigned to a pull request #{if sender then "by #{sender.name}" else ""}
        """
        author: sender
        footer: disableDisclaimer
        attachments: [ pr.toAttachment() ]

    @robot.on "GithubPullRequestReviewRequested", (pr, sender) =>
      @robot.logger.debug "Sending PR review request to #{pr.requested_reviewer.name}, sender is #{sender?.name}"
      @adapter.dm pr.requested_reviewer,
        text: """
          You have just been requested to review a pull request #{if sender then "by #{sender.name}" else ""}
        """
        author: sender
        footer: disableDisclaimer
        attachments: [ pr.toAttachment() ]

    @robot.on "GithubPullRequestReviewed", (pr, sender) =>
      @robot.logger.debug "Sending PR reviewed notice to #{pr.user.login}, sender is #{sender?.name}"
      @adapter.dm pr.creator,
        text: """
          Your pull request has been reviewed by #{if sender then "by #{sender.name}" else ""}
        """
        author: sender
        footer: disableDisclaimer
        attachments: [ pr.toAttachment() ]

  registerEventListeners: ->
    @robot.on "GithubPullRequestsOpenForRoom", (prs, room) =>
      if prs.length is 0
        message = text: "No matching pull requests found"
      else
        attachments = (pr.toAttachment() for pr in prs)
        message = attachments: attachments
      @send message: room: room.id, message

  registerRobotResponses: ->

    @robot.respond /(?:github|gh|git) (allow|start|enable|disallow|disable|stop)( notifications)?/i, (msg) =>
      [ __, state ] = msg.match
      switch state
        when "allow", "start", "enable"
          @adapter.enableNotificationsFor msg.message.user
          @send msg, """
          Github pull request notifications have been *enabled*

          You will start receiving notifications when you are assigned to a pull request on Github

          If you wish to _disable_ them just send me this message:
          > github disable notifications
          """
        when "disallow", "stop", "disable"
          @adapter.disableNotificationsFor msg.message.user
          @send msg, """
          Github pull request notifications have been *disabled*

          You will no longer receive notifications when you are assigned to a pull request on Github

          If you wish to _enable_ them again just send me this message:
          > github enable notifications
          """

    @robot.respond /(?:github|gh|git) delete all reminders/i, (msg) =>
      room = Utils.getRoom msg
      remindersCleared = @reminders.clearAllForRoom room.name
      @send msg, """
        Deleted #{remindersCleared} reminder#{if remindersCleared is 1 then "" else "s"}.
        No more reminders for you.
      """

    @robot.respond /(?:github|gh|git) delete ([0-5]?[0-9]:[0-5]?[0-9]) reminder/i, (msg) =>
      [__, time] = msg.match
      room = Utils.getRoom msg
      remindersCleared = @reminders.clearForRoomAtTime room.name, time
      if remindersCleared is 0
        @send msg, "Nice try. You don't even have a reminder at #{time}"
      else
        @send msg, "Deleted your #{time} reminder"

    @robot.respond /(?:github|gh|git) remind(?:er)? ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])$/i, (msg) =>
      [__, time] = msg.match
      room = Utils.getRoom msg
      @reminders.save room.name, time
      @send msg, "Ok, from now on I'll remind this room about open pull requests every weekday at #{time}"

    @robot.respond /(?:github|gh|git) list reminders$/i, (msg) =>
      room = Utils.getRoom msg
      reminders = @reminders.getForRoom room.name
      if reminders.length is 0
        @send msg, "Well this is awkward. You haven't got any github reminders set :-/"
      else
        @send msg, "You have pull request reminders at the following times: #{_.map(reminders, (reminder) -> reminder.time)}"

    @robot.respond /(?:github|gh|git) reminders in every room/i, (msg) =>
      reminders = @reminders.getAll()
      if reminders.length is 0
        @send msg, "No, because there aren't any."
      else
        @send msg, """
          Here's the reminders for every room: #{_.map(reminders, (reminder) -> "\nRoom: #{reminder.room}, Time: #{reminder.time}")}
        """

    @robot.respond /(github|gh|git) help/i, (msg) =>
      @send msg, """
        I can remind you about open pull requests for the repo that belongs to this channel
        Use me to create a reminder, and then I'll post in this room every weekday at the time you specify. Here's how:

        #{@robot.name} github open [for <user>] - Shows a list of open pull requests for the repo of this room [optionally for a specific user]
        #{@robot.name} github reminder hh:mm - I'll remind about open pull requests in this room at hh:mm every weekday.
        #{@robot.name} github list reminders - See all pull request reminders for this room.
        #{@robot.name} github reminders in every room - Be nosey and see when other rooms have their reminders set
        #{@robot.name} github delete hh:mm reminder - If you have a reminder at hh:mm, I'll delete it.
        #{@robot.name} github delete all reminders - Deletes all reminders for this room.
      """

    @robot.respond /(?:github|gh|git) (?:prs|open)(?:\s+(?:for|by)\s+(?:@?)(.*))?/i, (msg) =>
      [__, who] = msg.match

      if who is 'me'
        who = msg.message.user?.name?.toLowerCase()

      if who?
        who = @robot.brain.userForName who
        who = who.name

      room = Utils.getRoom msg
      Github.PullRequests.openForRoom(room, who)
      .catch (e) => @send msg, e

    @robot.hear /(?:https?:\/\/github\.com\/([a-z0-9-]+)\/)([a-z0-9-_.]+)\/pull\/(\d+)\/?\s*/i, (msg) =>
      [ url, org, repo, number ] = msg.match
      Github.PullRequest.fromUrl("#{Config.github.url}/repos/#{org}/#{repo}/pulls/#{number}")
      .then (pr) =>
        @robot.emit "JiraFindTicketMatches", "#{pr.title} #{pr.body}", (matches) =>
          if matches
            msg.match = _(matches).unique()
            @robot.emit "JiraPrepareResponseForTickets", msg

module.exports = GithubBot
