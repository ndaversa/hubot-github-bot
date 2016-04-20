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

    findMatch = (user) ->
      name = user.name or user.login
      return unless name
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
        threshold: 0.55

      results = f.search name
      result = if results? and results.length >=1 then results[0] else undefined
      return result

    if github.fetch?
      github.fetch().then findMatch
    else
      findMatch github

module.exports = Utils
