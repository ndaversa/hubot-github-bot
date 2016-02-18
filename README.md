# Hubot Github Bot

A hubot script to list and remind you about open pull requests

###Dependencies
- coffeescript
- cron
- octokat
- moment
- underscore
- fuse.js

###Configuration
- `HUBOT_GITHUB_TOKEN` - Github Application Token
- `HUBOT_GITHUB_ORG` - Github Organization Name (the one in the url)
- `HUBOT_GITHUB_REPOS_MAP` eg.`"{\"web\":\"frontend\",\"android\":\"android\",\"ios\":\"ios\",\"platform\":\"web\"}"`

###Commands
- hubot github open - Shows a list of open pull requests for the repo of this room
- hubot github notification hh:mm - I'll remind about open pull requests in this room at hh:mm every weekday.
- hubot github list notifications - See all pull request notifications for this room.
- hubot github notifications in every room - Be nosey and see when other rooms have their notifications set
- hubot github delete hh:mm notification - If you have a notification at hh:mm, I'll delete it.
- hubot github delete all notifications - Deletes all notifications for this room.
