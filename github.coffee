Promise = require 'bluebird'
{ Octokit } = require 'octokit'

daysToLookBack = 30

githubRateDelay = 200
delays = Promise.resolve()

octokit = null
exports.auth = (token) ->
  octokit = new Octokit {auth: token}
  octokit.rest.users.getAuthenticated()
  .then (a) -> console.log 'GitHub Hello', (JSON.stringify a, null, 2)
process.once 'beforeExit', (code) ->
  octokit.rest.users.getAuthenticated()
  .then (a) -> console.log 'GitHub Goodbye', (JSON.stringify a, null, 2)



exports.getIssueAndCommentsAsync = (githubUser, githubRepo, issueNumber) ->
  delays = delays.delay(githubRateDelay)
  delays.then -> Promise.resolve octokit.request 'GET /repos/{owner}/{repo}/issues/{issue_number}',
    owner: githubUser
    repo: githubRepo
    issue_number: issueNumber
  .then (issue) ->
    if issue.status isnt 200
      console.log "ERROR: issue #{issueNumber} issue.status isnt 200"
      throw issue
    expect = "/#{githubUser}/#{githubRepo}/issues/#{issueNumber}"
    # There's also html_url, but PRs are "pulls" there so we can't expect "issues"
    if not issue.data.url.endsWith expect
      console.log "ERROR: issue moved? '#{issue.data.url}' does not end with '#{expect}'"
      issue.issueMoved = true
      throw issue
    issue.data
  .then (issue) ->
    console.log "Downloading comments for issue #{issueNumber}..."
    delays = delays.delay(githubRateDelay)
    delays.then -> Promise.resolve octokit.paginate 'GET /repos/{owner}/{repo}/issues/{issue_number}/comments',
      owner: githubUser
      repo: githubRepo
      issue_number: issue.number
      per_page: 100
    .then (comments) ->
      console.log "Downloaded #{comments.length} comments for issue #{issue.number}."
      issue: issue
      comments: comments



exports.openIssuesAndCommentsAsync = (githubUser, githubRepo, issue_filter = (->true)) ->
  console.log "Downloading open issues..."
  delays = delays.delay(githubRateDelay)
  delays.then -> Promise.resolve octokit.paginate 'GET /repos/{owner}/{repo}/issues',
    owner: githubUser
    repo: githubRepo
    state: 'open'
    per_page: 100
    since: (new Date (new Date).getTime() - (daysToLookBack*24*60*60*1000)).toISOString()
  .filter issue_filter
  .then (issues) ->
    console.log "Downloaded #{issues.length} issues."
    console.log "Downloading comments for all open issues..."
    issues
  .map (issue) ->
    delays = delays.delay(githubRateDelay)
    delays.then -> Promise.resolve octokit.paginate 'GET /repos/{owner}/{repo}/issues/{issue_number}/comments',
      owner: githubUser
      repo: githubRepo
      issue_number: issue.number
      per_page: 100
    .then (comments) ->
      console.log "Downloaded #{comments.length} comments for issue #{issue.number}."
      issue: issue
      comments: comments
