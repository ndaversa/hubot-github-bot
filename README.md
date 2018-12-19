# Hubot Github Bot

A hubot script to list and recurrently remind you about open pull requests.
Optionally receive direct messages when you are assigned to a pull
request in your organization or for a specific repo or set of repos.

## Dependencies

- coffeescript
- cron
- octokat
- moment
- underscore
- fuse.js

## Configuration

- `HUBOT_GITHUB_TOKEN` - Github Application Token
- `HUBOT_GITHUB_WEBHOOK_SECRET` - Optional, if you are using webhooks and have a secret set this for additional security checks on payload delivery
- `HUBOT_GITHUB_URL` - Set this value if you are using Github Enterprise   default: `https://api.github.com`
- `HUBOT_GITHUB_ORG` - Github Organization Name (the one in the url)
- `HUBOT_GITHUB_REPOS_MAP` eg.`"{"web":["frontend","web"],"android":["android"],"ios":["ios"],"platform":["web"]}"`

Note: As of v3.3 the `HUBOT_GITHUB_REPOS_MAP` now expects an array for
the value in the map to support multiple repos per channel

## Commands

- hubot github open - Shows a list of open pull requests for the repo of this room
- hubot github reminder hh:mm - I'll remind about open pull requests in this room at hh:mm every weekday.
- hubot github list reminders - See all pull request reminders for this room.
- hubot github reminders in every room - Be nosey and see when other rooms have their reminders set
- hubot github delete hh:mm reminder - If you have a reminder at hh:mm, I'll delete it.
- hubot github delete all reminders - Deletes all reminders for this room.

### Notifications via Webhooks

In order to receive github notifications you will need to setup a github
webhook for either your entire organization or per repository. You can
find instructions to do so on [Github's website](https://developer.github.com/webhooks/creating/).
You will need your hubot to be reachable from the outside world for this
to work. GithubBot is listening on `/hubot/github-events`. Currently
the following notifications are available:

* Pull Request Assignment (please ensure the webhook sends pull request events for this to work)

Note: in order for direct messages (notifications) to work GithubBot attempts to
fuzzy match the github name or github login to someone on your team. It
has been tested primarily on the [Hubot Slack adapter](https://github.com/slackhq/hubot-slack), but it should work
elsewhere. If GithubBot cannot find a matching user it drops the
notification and logs the failure to the console.
