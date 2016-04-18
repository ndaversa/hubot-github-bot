_ = require 'underscore'
moment = require 'moment'
cronJob = require("cron").CronJob

class Reminders
  constructor: (@robot, @key, @cb) ->
    @robot.brain.once 'loaded', =>
      # Run a cron job that runs every minute, Monday-Friday
      new cronJob('0 * * * * 1-5', @_check.bind(@), null, true)

  _get: ->
    @robot.brain.get(@key) or []

  _save: (reminders) ->
    @robot.brain.set @key, reminders

  _check: ->
    reminders = @_get()
    _.chain(reminders).filter(@_shouldFire).pluck('room').each @cb

  _shouldFire: (reminder) ->
    now = new Date
    currentHours = now.getHours()
    currentMinutes = now.getMinutes()
    reminderHours = reminder.time.split(':')[0]
    reminderMinutes = reminder.time.split(':')[1]
    try
      reminderHours = parseInt reminderHours, 10
      reminderMinutes = parseInt reminderMinutes, 10
    catch _error
      return false
    if reminderHours is currentHours and reminderMinutes is currentMinutes
      return true
    return false

  getAll: ->
    @_get()

  getForRoom: (room) ->
    _.where @_get(), room: room

  save: (room, time) ->
    reminders = @_get()
    newReminder =
      time: time
      room: room
    reminders.push newReminder
    @_save reminders

  clearAllForRoom: (room) ->
    reminders = @_get()
    remindersToKeep = _.reject(reminders, room: room)
    @_save remindersToKeep
    reminders.length - (remindersToKeep.length)

  clearForRoomAtTime: (room, time) ->
    reminders = @_get()
    remindersToKeep = _.reject reminders,
      room: room
      time: time
    @_save remindersToKeep
    reminders.length - (remindersToKeep.length)

module.exports = Reminders
