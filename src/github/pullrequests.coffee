_ = require "underscore"

Octokat = require "octokat"
Config = require "../config"
PullRequest = require "./pullrequest"
Utils = require "../utils"

octo = new Octokat
  token: Config.github.token
  rootUrl: Config.github.url

class PullRequests

  @openForRoom: (room, user) ->
    repos = Config.maps.repos[room.name]
    return Promise.reject "There is no github repository associated with this room. Contact your friendly <@#{robot.name}> administrator for assistance" unless repos

    Promise.all( repos.map (repo) ->
      repo = octo.repos(Config.github.organization, repo)
      repo.pulls.fetch(state: "open")
      .then (json) ->
        return Promise.all json.items.map (pr) ->
          if user?
            return if not pr.assignee?
            github = octo.fromUrl(pr.assignee.url)
            return Utils.lookupUserWithGithub(github).then (assignee) ->
              return if user.toLowerCase() isnt assignee?.name.toLowerCase()
              return repo.pulls(pr.number).fetch()
          else
            return repo.pulls(pr.number).fetch()
      .then (prs) ->
        return Promise.all prs.map (pr) ->
          return if not pr
          github = octo.fromUrl(pr.assignee.url) if pr.assignee?.url
          assignee = Utils.lookupUserWithGithub github
          return Promise.all [ pr, assignee ]
    )
    .then (repos) ->
      pullRequests = []
      for repo in repos
        for p in repo when p
          pullRequests.push new PullRequest p[0], p[1]
      Utils.robot.emit "GithubPullRequestsOpenForRoom", pullRequests, room
      pullRequests
    .catch ( error ) ->
      Utils.robot.logger.error error
      Promise.reject error

module.exports = PullRequests
