class Config
  @debug: process.env.HUBOT_GITHUB_DEBUG

  @github:
    url: process.env.HUBOT_GITHUB_URL or "https://api.github.com"
    token: process.env.HUBOT_GITHUB_TOKEN
    organization: process.env.HUBOT_GITHUB_ORG

  @maps:
    repos: JSON.parse process.env.HUBOT_GITHUB_REPOS_MAP if process.env.HUBOT_GITHUB_REPOS_MAP

unless Config.maps.repos
  throw new Error "You must specify a room->repo mapping in the environment as HUBOT_GITHUB_REPOS_MAP, see README.md for details"

module.exports = Config
