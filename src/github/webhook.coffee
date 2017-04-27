Config = require "../config"
Octokat = require "octokat"
Utils = require "../utils"
PullRequest = require "./pullrequest"

url = require "url"
crypto = require "crypto"

octo = new Octokat
  token: Config.github.token
  rootUrl: Config.github.url

class Webhook
  constructor: (@robot) ->
    @robot.router.post "/hubot/github-events", (req, res) =>
      return unless req.body?
      hmac = crypto.createHmac "sha1", Config.github.webhook.secret if Config.github.webhook.secret
      if hmac and hubSignature = req.headers["x-hub-signature"]
        hmac.update JSON.stringify req.body
        signature = "sha1=#{hmac.digest "hex"}"
        unless signature is hubSignature
          return @robot.logger.error "Github Webhook Signature did not match, aborting"

      event = req.body

      if req.body.pull_request
        @onPullRequest event

      res.send 'OK'

  onPullRequest: (event) ->
    switch event.action
      when "assigned"
        @onPullRequestAssignment event
      when "review_requested"
        @onPullRequestReviewRequested event

  onPullRequestAssignment: (event) ->
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
        Utils.robot.logger.error "Github Webhook: Unable to find webhook sender #{event.sender.login}"
      .then ->
        PullRequest.fromUrl event.pull_request.url
    .then (pr) ->
      pr.assignee = user
      @robot.emit "GithubPullRequestAssigned", pr, sender
    .catch (error) ->
      Utils.robot.logger.error "Github Webhook: Unable to find user to send notification to #{event.assignee.login}"
      Utils.robot.logger.error error
      Utils.robot.logger.error error.stack

  onPullRequestReviewRequested: (event) -> 
    return unless event.requested_reviewer?.url?

    user = null
    sender = null
    Utils.lookupUserWithGithub(octo.fromUrl(event.requested_reviewer.url))
    .then (u) ->
      user = u
      Utils.lookupUserWithGithub(octo.fromUrl(event.sender.url))
      .then (s) ->
        sender = s
      .catch (error) ->
        Utils.robot.logger.error "Github Webhook: Unable to find webhook sender #{event.sender.login}"
      .then ->
        PullRequest.fromUrl event.pull_request.url
    .then (pr) ->
      pr.requested_reviewer = user
      @robot.emit "GithubPullRequestReviewRequested", pr, sender
    .catch (error) ->
      Utils.robot.logger.error "Github Webhook: Unable to find user to send notification to #{event.requested_reviewer.login}"
      Utils.robot.logger.error error
      Utils.robot.logger.error error.stack

module.exports = Webhook
