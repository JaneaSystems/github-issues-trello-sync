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
  .option '-a, --area-path <path>', 'VSTS Area Path to use'
  .parse process.argv

if not program.vstsInstance or
   not program.vstsProject or
   not program.vstsUser or
   not program.vstsToken or
   not program.areaPath
     program.help()
     return 0


vsts.auth program.vstsInstance, program.vstsProject, 'Basic ' + (Buffer.from "#{program.vstsUser}:#{program.vstsToken}").toString 'base64'


storiesP = vsts.runWiql "select [System.Id] from Workitems where [System.AreaPath] = '#{program.areaPath}'"
.then vsts.getWorkItemsAsync
.tap (workitems) -> require('jsonfile').writeFileSync 'backup.json', workitems, { spaces: 2 }
