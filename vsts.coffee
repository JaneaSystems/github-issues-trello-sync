Promise = require 'bluebird'
_ = require 'lodash'
request = Promise.promisifyAll require 'request'
prettyjson = require 'prettyjson'



vstsRateDelay = 200
delays = Promise.resolve()
auth = null
instanceUrl = null
project = null

exports.auth = (instanceStr, projectStr, authStr) ->
  instanceUrl = "https://#{instanceStr}.visualstudio.com/"
  project = projectStr
  auth = _.bind _.set, null, _, 'Authorization', authStr



apiCall = (log, ifunc, arg0, retriesLeft = 10) ->
  func = ifunc.bind request
  delays = delays.delay vstsRateDelay
  delays.then ->
    console.log log
    if retriesLeft is 0
      console.log 'Exausted retries.'
      process.abort()
    func arg0
  .catch (e) ->
    console.log log
    if e.code is '504'
      console.log '504 error found, will retry'
      apiCall log, func, arg0, (retriesLeft - 1)
    else
      console.log e
      console.log e.stack
      process.abort()
  .tap (res) ->
    if res.statusCode isnt 200
      console.log res
      console.log res.statusCode
      console.log res.statusMessage
      console.error "\nERROR:\n#{prettyjson.render JSON.parse res.body}\n"
      throw res



# https://www.visualstudio.com/en-us/docs/integrate/api/wit/work-items#create-a-work-item
exports.createWorkItem = (type, body) ->
  apiCall "Creating a new Work Item of Type #{type}...",
    request.patchAsync,
    url: "#{instanceUrl}DefaultCollection/#{project}/_apis/wit/workitems/$#{type}?api-version=1.0"
    headers: auth
      'Content-Type': 'application/json-patch+json'
    body: JSON.stringify body

exports.getWorkItemById = (id) ->
  apiCall "Getting Work Item with ID #{id}...",
    request.getAsync,
    url: "#{instanceUrl}DefaultCollection/_apis/wit/workitems?api-version=1.0&ids=#{id}&$expand=all"
    headers: auth {}

exports.list = () ->
  apiCall "Getting a list of Queries...",
    request.getAsync,
    url: "#{instanceUrl}DefaultCollection/#{project}/_apis/wit/queries/Shared Queries?api-version=2.2&$depth=2&expand=all"
    headers: auth {}

exports.runWiql = (wiql) ->
  apiCall "Running WIQL: \"#{wiql}\"...",
    request.postAsync,
    url: "#{instanceUrl}#{project}/_apis/wit/wiql?api-version=1.0"
    headers: auth
      'Content-Type': 'application/json'
    body: JSON.stringify
      query: wiql

exports.getWorkItemsAsync = (queryResult) ->
  Promise.resolve queryResult
  .then (res) -> res.body
  .then JSON.parse
  .then (qr) -> qr.workItems
  .map (wi) -> wi.id
  .map exports.getWorkItemById
  .map (res) -> res.body
  .map JSON.parse
  .map (wi) -> wi.value[0]

exports.getWorkItemByTypeTitle = (type, title) ->
  vsts.runWiql "select [System.Id] from Workitems where [System.TeamProject] = @project and [System.WorkItemType] = 'Epic' and [System.Title] = 'Epic1'"
  .then vsts.getWorkItemsAsync
  # TODO, then check for empty array or array with 1 elem
