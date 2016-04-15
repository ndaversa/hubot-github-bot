_ = require "underscore"
Fuse = require "fuse.js"

class Utils
  @robot: null

  @findRoom: (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  @lookupUserWithGithub: (github) ->
    return if not github

    github.fetch().then (user) ->
      name = user.name or github.login
      users = Utils.robot.brain.users()
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

module.exports = Utils
