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


importRound = () ->
  trello.getCardsOnList importFromListId
  .each (card) ->
    vsts.createWorkItem 'Task', [
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
    ]
    .catch process.abort
    .tap () -> trello.moveCardToListAsync card.id, moveToListId
    .catch process.abort


listsP.tap importRound
