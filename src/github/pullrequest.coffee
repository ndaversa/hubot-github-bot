moment = require "moment"
Octokat = require "octokat"

Config = require "../config"
Utils = require "../utils"

octo = new Octokat token: Config.github.token

class PullRequest
  @fromUrl: (url) ->
    octo.fromUrl(url).fetch()
    .then (pr) ->
      new PullRequest pr

  constructor: (json, @assignee) ->
    @[k] = v for k,v of json when k isnt "assignee"

  toAttachment: ->
    color: "#ff9933"
    author_name: @user.login
    author_icon: @user.avatarUrl
    author_link: @user.htmlUrl
    title: @title
    title_link: @htmlUrl
    fields: [
      title: "Created"
      value: moment(@createdAt).fromNow()
      short: yes
    ,
      title: "Updated"
      value: moment(@updatedAt).fromNow()
      short: yes
    ,
      title: "Status"
      value: if @mergeable then "Mergeable" else "Unresolved Conflicts"
      short: yes
    ,
      title: "Assignee"
      value: if @assignee then "<@#{@assignee.id}>" else "Unassigned"
      short: yes
    ,
      title: "Lines"
      value: "+#{@additions} -#{@deletions}"
      short: yes
    ]
    fallback: """
      *#{@title}* +#{@additions} -#{@deletions}
      Created: *#{moment(@createdAt).fromNow()}*
      Updated: *#{moment(@updatedAt).fromNow()}*
      Status: #{if @mergeable then "Mergeable" else "Unresolved Conflicts"}
      Author: #{@user.login}
      Assignee: #{if @assignee then "#{@assignee.name}" else "Unassigned"}
    """

module.exports = PullRequest
