﻿Promise = require 'bluebird'
GitHubApi = require 'github'



auth = null
githubRateDelay = 200
delays = Promise.resolve()
github = new GitHubApi
  version: "3.0.0"
  debug: true
  protocol: "https"
  host: "api.github.com"
  timeout: 5000
Promise.promisifyAll github.issues

exports.auth = (token) ->
  auth = -> github.authenticate
    type: 'oauth'
    token: token
  null



apiCall = (log, func, arg, retriesLeft = 10) ->
  delays = delays.delay(githubRateDelay)
  delays.then ->
    console.log log
    if retriesLeft is 0
      console.log "Exausted retries."
      process.abort()
    auth() if auth?
    func(arg)
  .catch (e) ->
    if e.code is '504' or e.code is 504
      console.log '504 error found, will retry'
      apiCall log, func, arg, (retriesLeft - 1)
    else if e.code is '404' or e.code is 404
      throw e
    else if e.code is '410' or e.code is 410
      throw e
    else
      console.log e
      process.abort()



getAllPages = (func, arg, filterFunc = (->true), acc = [], pageNumber = 1) ->
  arg['per_page'] = 100
  arg['page'] = pageNumber
  apiCall "Getting page #{pageNumber} ...", func, arg
  .then (res) ->
    res = res.filter filterFunc
    console.log 'Received page ' + pageNumber + ' containing ' + res.length + ' items.'
    # Single page for debug
    # return res;
    res.forEach (v) -> acc.push v
    if res.length is 0 or res.length < 100
      console.log 'Done getting pages. Received ' + acc.length + ' items.'
      acc
    else
      getAllPages func, arg, filterFunc, acc, pageNumber + 1



exports.getIssueAndCommentsAsync = (githubUser, githubRepo, issueNumber) ->
  apiCall "Downloading issue #{issueNumber}...", github.issues.getRepoIssueAsync,
    user: githubUser
    repo: githubRepo
    number: issueNumber
  .then (issue) ->
    if issue.meta?.status isnt '200 OK'
      console.log "issue #{issueNumber} issue.meta.status isnt '200 OK'"
      console.log issue.meta
      throw new Error()
    console.log "Downloading comments for issue #{issueNumber}..."
    getAllPages github.issues.getCommentsAsync,
      user: githubUser
      repo: githubRepo
      number: issue.number
    .then (comments) ->
      console.log "Downloaded #{comments.length} comments for issue #{issue.number}."
      issue: issue
      comments: comments



exports.openIssuesAndCommentsAsync = (githubUser, githubRepo, issue_filter = (->true)) ->
  console.log "Downloading open issues..."
  getAllPages github.issues.repoIssuesAsync,
    user: githubUser
    repo: githubRepo
    state: 'open'
  .filter issue_filter
  .then (issues) ->
    console.log "Downloaded #{issues.length} issues."
    console.log "Downloading comments for all open issues..."
    issues
  .map (issue) ->
    getAllPages github.issues.getCommentsAsync,
      user: githubUser
      repo: githubRepo
      number: issue.number
    .then (comments) ->
      console.log "Downloaded #{comments.length} comments for issue #{issue.number}."
      issue: issue
      comments: comments
