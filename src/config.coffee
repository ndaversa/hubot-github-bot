class Config
  @debug: process.env.HUBOT_GITHUB_DEBUG

  @github:
    token: process.env.HUBOT_GITHUB_TOKEN
    organization: process.env.HUBOT_GITHUB_ORG

  @maps:
    repos: JSON.parse process.env.HUBOT_GITHUB_REPOS_MAP

module.exports = Config
