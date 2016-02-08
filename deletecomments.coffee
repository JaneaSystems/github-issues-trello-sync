packageJson = require './package.json'
program = require 'commander'
Promise = require 'bluebird'
prettyjson = require 'prettyjson'

require 'coffee-script/register'
trello = require './trello.coffee'



program
  .version packageJson.version
  .usage '-k <trello-key> -t <trello-token> -b <trello-board> -i <commenter-id>'
  .option '-k, --trello-key <key>', 'Trello key'
  .option '-t, --trello-token <token>', 'Trello auth token'
  .option '-b, --trello-board <id>', 'Trello board ID'
  .option '-i, --trello-commenter-id <id>', 'Delete comments created by this Id'
  .option '-n, --no-commit', 'Calculate modifications but do not write them to Trello'
  .parse process.argv

if not program.trelloKey or
   not program.trelloToken or
   not program.trelloBoard or
   not program.trelloCommenterId
     program.help()
     return 0



trello.auth program.trelloKey, program.trelloToken



allCardsP = trello.getCardsOnBoard program.trelloBoard
.map (card) ->
  trello.getCommentsOnCard card.id
  .map (comment) ->
    if comment.idMemberCreator is program.trelloCommenterId
      console.log "Will delete comment #{comment.id} on card \"#{card.name}\""
      if program.commit
        trello.deleteCommentAsync comment.id
