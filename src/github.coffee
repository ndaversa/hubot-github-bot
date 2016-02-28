# Description:
#  List and schedule reminders about open pull requests on github
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
#   HUBOT_GITHUB_ORG - Github Organization Name (the one in the url)
#   HUBOT_GITHUB_REPOS_MAP (format: "{\"web\":\"frontend\",\"android\":\"android\",\"ios\":\"ios\",\"platform\":\"web\"}"
#
# Commands:
#   hubot github open [for <user>] - Shows a list of open pull requests for the repo of this room [optionally for a specific user]
#   hubot github notification hh:mm - I'll remind about open pull requests in this room at hh:mm every weekday.
#   hubot github list notifications - See all pull request notifications for this room.
#   hubot github notifications in every room - Be nosey and see when other rooms have their notifications set
#   hubot github delete hh:mm notification - If you have a notification at hh:mm, I'll delete it.
#   hubot github delete all notifications - Deletes all notifications for this room.
#
# Author:
#   ndaversa

token = process.env.HUBOT_GITHUB_TOKEN
githubOrg = process.env.HUBOT_GITHUB_ORG
repos = JSON.parse process.env.HUBOT_GITHUB_REPOS_MAP
debug = process.env.HUBOT_GITHUB_DEBUG

_ = require 'underscore'
moment = require 'moment'
cronJob = require("cron").CronJob
Octokat = require('octokat')
octo = new Octokat token: token
Fuse = require 'fuse.js'

module.exports = (robot) ->

  send = (context, message, prependUsername=no) ->
    robot.adapter.customMessage
      channel: context.message.room
      text: "#{if prependUsername then "<@#{context.message.user.id}> " else ""}#{message}"

  getNotifications = ->
    robot.brain.get('github-notifications') or []

  saveNotifications = (notifications) ->
    robot.brain.set 'github-notifications', notifications

  lookupUserWithGithub = (github) ->
    return if not github

    github.fetch().then (user) ->
      name = user.name or github.login
      users = robot.brain.users()
      users = _(users).keys().map (id) ->
        u = users[id]
        id: u.id
        name: u.name
        real_name: u.real_name

      f = new Fuse users,
        keys: ['real_name']
        shouldSort: yes
        verbose: no

      results = f.search name
      result = if results? and results.length >=1 then results[0] else undefined
      return result

  notificationShouldFire = (notification) ->
    now = new Date
    currentHours = now.getHours()
    currentMinutes = now.getMinutes()
    notificationHours = notification.time.split(':')[0]
    notificationMinutes = notification.time.split(':')[1]
    try
      notificationHours = parseInt notificationHours, 10
      notificationMinutes = parseInt notificationMinutes, 10
    catch _error
      return false
    if notificationHours is currentHours and notificationMinutes is currentMinutes
      return true
    return false

  getNotificationsForRoom = (room) ->
    _.where getNotifications(), room: room

  checkNotifications = ->
    notifications = getNotifications()
    _.chain(notifications).filter(notificationShouldFire).pluck('room').each doNotification

  doNotification = (room) ->
    listOpenPullRequestsForRoom room

  findRoom = (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  saveNotification = (room, time) ->
    notifications = getNotifications()
    newNotification =
      time: time
      room: room
    notifications.push newNotification
    saveNotifications notifications

  clearAllNotificationsForRoom = (room) ->
    notifications = getNotifications()
    notificationsToKeep = _.reject(notifications, room: room)
    saveNotifications notificationsToKeep
    notifications.length - (notificationsToKeep.length)

  clearSpecificNotificationForRoom = (room, time) ->
    notifications = getNotifications()
    notificationsToKeep = _.reject notifications,
      room: room
      time: time
    saveNotifications notificationsToKeep
    notifications.length - (notificationsToKeep.length)

  listOpenPullRequestsForRoom = (room, user) ->
    repo = repos[room]
    if not repo
      send message: room: room, "There is no github repository associated with this room. Contact your friendly <@#{robot.name}> administrator for assistance"
      return

    repo = octo.repos(githubOrg, repo)
    repo.pulls.fetch(state: "open")
    .then (prs) ->
      return Promise.all prs.map (pr) ->
        if user?
          return if not pr.assignee?
          return lookupUserWithGithub(pr.assignee).then (assignee) ->
            return if user.toLowerCase() isnt assignee?.name.toLowerCase()
            return repo.pulls(pr.number).fetch()
        else
          return repo.pulls(pr.number).fetch()
    .then (prs) ->
      return Promise.all prs.map (pr) ->
        return if not pr
        author = lookupUserWithGithub pr.user
        assignee = lookupUserWithGithub pr.assignee
        return Promise.all [ pr, author, assignee ]
    .then (prs) ->
      message = ""
      for p in prs when p
        pr = p[0]
        author = p[1]
        assignee = p[2]
        message+= """
          *<#{pr.htmlUrl}|#{pr.title}>* +#{pr.additions} -#{pr.deletions}
          Updated: *#{moment(pr.updatedAt).fromNow()}*
          Status: #{if pr.mergeable then "Mergeable" else "Unresolved Conflicts"}
          Author: #{if author then "<@#{author.id}>" else "Unknown"}
          Assignee: #{if assignee then "<@#{assignee.id}>" else "Unassigned"}
          \n
        """
      if message.length is 0
        message = "No matching pull requests found"

      send message: room: room, message
    .catch ( error ) ->
      console.log error.stack

  robot.respond /(?:github|gh|git) delete all notifications/i, (msg) ->
    notificationsCleared = clearAllNotificationsForRoom(findRoom(msg))
    send msg, """
      Deleted #{notificationsCleared} notification#{if notificationsCleared is 1 then "" else "s"}.
      No more notifications for you.
    """

  robot.respond /(?:github|gh|git) delete ([0-5]?[0-9]:[0-5]?[0-9]) notification/i, (msg) ->
    [__, time] = msg.match
    notificationsCleared = clearSpecificNotificationForRoom(findRoom(msg), time)
    if notificationsCleared is 0
      send msg, "Nice try. You don't even have a notification at #{time}"
    else
      send msg, "Deleted your #{time} notification"

  robot.respond /(?:github|gh|git) notification ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])$/i, (msg) ->
    [__, time] = msg.match
    room = findRoom(msg)
    saveNotification room, time
    send msg, "Ok, from now on I'll remind this room about open pull requests every weekday at #{time}"

  robot.respond /(?:github|gh|git) list notifications$/i, (msg) ->
    notifications = getNotificationsForRoom(findRoom(msg))
    if notifications.length is 0
      send msg, "Well this is awkward. You haven't got any github notifications set :-/"
    else
      send msg, "You have pull request notifcations at the following times: #{_.map(notifications, (notification) -> notification.time)}"

  robot.respond /(?:github|gh|git) notifications in every room/i, (msg) ->
    notifications = getNotifications()
    if notifications.length is 0
      send msg, "No, because there aren't any."
    else
      send msg, """
        Here's the notifications for every room: #{_.map(notifications, (notification) -> "\nRoom: #{notification.room}, Time: #{notification.time}")}
      """

  robot.respond /(github|gh|git) help/i, (msg) ->
    send msg, """
      I can remind you about open pull requests for the repo that belongs to this channel
      Use me to create a notification, and then I'll post in this room every weekday at the time you specify. Here's how:

      #{robot.name} github open [for <user>] - Shows a list of open pull requests for the repo of this room [optionally for a specific user]
      #{robot.name} github notification hh:mm - I'll remind about open pull requests in this room at hh:mm every weekday.
      #{robot.name} github list notifications - See all pull request notifications for this room.
      #{robot.name} github notifications in every room - Be nosey and see when other rooms have their notifications set
      #{robot.name} github delete hh:mm notification - If you have a notification at hh:mm, I'll delete it.
      #{robot.name} github delete all notifications - Deletes all notifications for this room.
    """

  robot.respond /(?:github|gh|git) (?:prs|open)(?:\s+(?:for|by)\s+(?:@?)(.*))?/i, (msg) ->
    [__, who] = msg.match

    if who is 'me'
      who = msg.message.user?.name?.toLowerCase()

    if who?
      who = robot.brain.userForName who
      who = who.name

    listOpenPullRequestsForRoom msg.message.room, who

  robot.brain.once 'loaded', ->
    # Run a cron job that runs every minute, Monday-Friday
    new cronJob('0 * * * * 1-5', checkNotifications, null, true)
