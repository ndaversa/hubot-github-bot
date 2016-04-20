Octokat = require "octokat"
Config = require "../config"
PullRequest = require "./pullrequest"
Utils = require "../utils"

octo = new Octokat token: Config.github.token

class PullRequests

  @openForRoom: (room, user) ->
    repo = Config.maps.repos[room]
    throw "There is no github repository associated with this room. Contact your friendly <@#{robot.name}> administrator for assistance" unless repo

    repo = octo.repos(Config.github.organization, repo)
    repo.pulls.fetch(state: "open")
    .then (json) ->
      return Promise.all json.items.map (pr) ->
        if user?
          return if not pr.assignee?
          return Utils.lookupUserWithGithub(pr.assignee).then (assignee) ->
            return if user.toLowerCase() isnt assignee?.name.toLowerCase()
            return repo.pulls(pr.number).fetch()
        else
          return repo.pulls(pr.number).fetch()
    .then (prs) ->
      return Promise.all prs.map (pr) ->
        return if not pr
        assignee = Utils.lookupUserWithGithub pr.assignee
        return Promise.all [ pr, assignee ]
    .then (prs) ->
      pullRequests = []
      pullRequests.push new PullRequest p[0], p[1] for p in prs when p
      Utils.robot.emit "GithubPullRequestsOpenForRoom", pullRequests, room
      pullRequests
    .catch ( error ) ->
      Utils.robot.logger.error error.stack
      Promise.reject error

module.exports = PullRequests
