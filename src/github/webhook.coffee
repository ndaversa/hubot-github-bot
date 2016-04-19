Config = require "../config"
Octokat = require "octokat"
Utils = require "../utils"
PullRequest = require "./pullrequest"

octo = new Octokat token: Config.github.token

class Webhook
  constructor: (@robot) ->
    @robot.router.post "/hubot/github-events", (req, res) =>
      return unless req.body?
      event = req.body

      if req.body.pull_request
        @onPullRequest event

      res.send 'OK'

  onPullRequest: (event) ->
    return unless event.action is "assigned"
    return unless event.assignee?.url?

    user = null
    sender = null
    Utils.lookupUserWithGithub(octo.fromUrl(event.assignee.url))
    .then (u) ->
      user = u
      Utils.lookupUserWithGithub(octo.fromUrl(event.sender.url))
      .then (s) ->
        sender = s
      .catch (error) ->
        Utils.robot.logger.error "Unable to find webhook sender #{event.sender.login}"
      .then ->
        PullRequest.fromUrl event.pull_request.url
    .then (pr) ->
      pr.assignee = user
      @robot.emit "GithubPullRequestAssigned", pr, sender
    .catch (error) ->
      Utils.robot.logger.error error
      Utils.robot.logger.error error.stack


module.exports = Webhook
