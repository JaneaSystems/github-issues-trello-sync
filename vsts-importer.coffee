packageJson = require './package.json'
program = require 'commander'
Promise = require 'bluebird'
PromiseQueue = require 'promise-queue'
PromiseQueue.configure Promise
prettyjson = require 'prettyjson'
_ = require 'lodash'
marked = require 'marked'
inquirer = require 'inquirer'

require 'coffee-script/register'
trello = require './trello.coffee'
vsts = require './vsts.coffee'


program
  .version packageJson.version
  .option '-n, --dry-run', 'Do a dry-run'
  .option '-i, --vsts-instance <name>', 'VSTS instance name'
  .option '-p, --vsts-project <name>', 'VSTS project name'
  .option '-u, --vsts-user <user>', 'VSTS user name'
  .option '-s, --vsts-token <token>', 'VSTS token'
  .option '-k, --trello-key <key>', 'Trello key'
  .option '-t, --trello-token <token>', 'Trello auth token'
  .option '-b, --trello-board <id>', 'Trello board ID'
  .option '-a, --area-path <path>', 'VSTS Area Path to use'
  .option '-f, --list-from <name>', 'Source list in Trello'
  .option '-d, --list-dest <name>', 'Move-to list in Trello'
  .parse process.argv

if not program.vstsInstance or
   not program.vstsProject or
   not program.vstsUser or
   not program.vstsToken or
   not program.trelloKey or
   not program.trelloToken or
   not program.trelloBoard or
   not program.areaPath or
   not program.listFrom or
   not program.listDest
     program.help()
     return 0


vsts.auth program.vstsInstance, program.vstsProject, 'Basic ' + (Buffer.from "#{program.vstsUser}:#{program.vstsToken}").toString 'base64'
trello.auth program.trelloKey, program.trelloToken


importFromListId = null
moveToListId = null

listsP = trello.getListsOnBoardAsync program.trelloBoard
.reduce (acc, list) ->
  acc.nameToId[list.name] = list.id
  acc.idToName[list.id] = list.name
  acc
, { nameToId: {}, idToName: {} }
.tap (lists) ->
  importFromListId = lists.nameToId[program.listFrom]
  unless importFromListId
    console.error 'Could not find source list on Trello'
    process.abort()
  moveToListId = lists.nameToId[program.listDest]
  unless moveToListId
    console.error 'Could not find move-to list on Trello'
    process.abort()


stories = null
priorities = [{ name: 'No Priority', value: null }, { name: 'P0', value: '0' }, { name: 'P1', value: '1' }, { name: 'P2', value: '2' }, { name: 'P3', value: '3' }]

storiesP = vsts.runWiql "select [System.Id] from Workitems where [System.AreaPath] = '#{program.areaPath}' and [System.WorkItemType] = 'User Story' and [System.State] <> 'Cut'"
.then vsts.getWorkItemsAsync
.then (workitems) -> stories = [{ name: 'No User Story', value: null }].concat ({ name: wi.fields["System.Title"], value: wi._links.self.href } for wi in workitems)


importRound = () ->
  trello.getCardsOnList importFromListId
  .each (card) ->
    console.log()
    console.log "Importing: #{card.name}"
    bodyP = Promise.resolve inquirer.prompt [
      type: 'list'
      name: 'userstory'
      message: 'Add a Parent Link to User Story?'
      choices: stories
    ,
      type: 'list'
      name: 'priority'
      message: 'Assign a Priority?'
      choices: priorities
    ]
    .then (answers) ->
      body = [
        'op': 'add'
        'path': '/fields/System.AreaPath'
        'value': program.areaPath
      ,
        'op': 'add'
        'path': '/fields/System.Title'
        'value': card.name
      ,
        'op': 'add'
        'path': '/fields/System.Description'
        'value': marked card.desc, { breaks: true }
      ,
        'op': 'add'
        'path': '/fields/Microsoft.VSTS.Common.Priority'
        'value': (if answers.priority isnt null then answers.priority else '')
      ]
      if answers.userstory isnt null then body.push
        'op': 'add'
        'path': '/relations/-'
        'value':
          'rel': 'System.LinkTypes.Hierarchy-Reverse'
          'url': answers.userstory
      body
    .then (body) ->
      if program.dryRun
        console.log card.id
        console.log body
      else
        vsts.createWorkItem 'Task', body 
        .catch process.abort
        .tap () -> trello.moveCardToListAsync card.id, moveToListId
        .catch process.abort


listsP.tap storiesP.tap importRound
