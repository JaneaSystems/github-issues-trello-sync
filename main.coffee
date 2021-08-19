packageJson = require './package.json'
program = require 'commander'
Promise = require 'bluebird'
PromiseQueue = require 'promise-queue'
PromiseQueue.configure Promise
prettyjson = require 'prettyjson'

require 'coffee-script/register'
github = require './github.coffee'
trello = require './trello.coffee'
textgen = require './textgen.coffee'



collect = (val, memo) ->
  memo.push val
  memo
program
  .version packageJson.version
  .usage '-u <github-user> -r <github-repo> [-g github-token] -k <trello-key> -t <trello-token> -b <trello-board> [KEYWORDS...]'
  .option '-u, --github-user <user>', 'Github user or organization hosting the repository'
  .option '-r, --github-repo <repo>', 'Github repository name'
  .option '-g, --github-token <repo>', 'optional Github OAuth2 token'
  .option '-k, --trello-key <key>', 'Trello key'
  .option '-t, --trello-token <token>', 'Trello auth token'
  .option '-b, --trello-board <id>', 'Trello board ID'
  .option '-a, --archive-from-inbox', 'Archive cards for closed issues in inbox'
  .option '-p, --include-pull-requests', 'Include pull requests'
  .option '-f, --full-text', 'Reproduce full issue text on trello'
  .option '-n, --no-commit', 'Download and calculate modifications but do not write them to Trello'
  .option '-w, --warn <KEYWORD>', 'Warn about mentions of KEYWORD', collect, []
  .parse process.argv

if not program.githubUser or
   not program.githubRepo or
   not program.trelloKey or
   not program.trelloToken or
   not program.trelloBoard
     program.help()
     return 0



trello.auth program.trelloKey, program.trelloToken
github.auth program.githubToken if program.githubToken?
keywords = program.args



# There are 3 types of actions to consider:
# - New issues, not in trello (github: open, trello: unknown)
# - Known issues, open (github: open, trello: present)
# - Known issues, closed (github: get one by one, trello: present)



inboxListIdP = trello.findListIdAsync 'Inbox', program.trelloBoard

labelsP = trello.getLabelsOnBoard program.trelloBoard
.then (labels) ->
  expectedLabels = keywords.concat ['CLOSED', 'MOVED']
  missingLabels = (keyword for keyword in expectedLabels when not labels.some((label) -> label.name is keyword))
  Promise.map missingLabels, (missingLabel) ->
    # TODO: Should respect program.commit
    console.log "Adding missing label #{missingLabel}..."
    trello.addLabelToBoardAsync program.trelloBoard, missingLabel
    .tap (label) ->
      labels.push label
  .then -> labels
.then (labels) ->
  nameToId = {}
  idToName = {}
  for label in labels
    nameToId[label.name] = label.id
    idToName[label.id] = label.name
  nameToId: nameToId
  idToName: idToName
.then (res) -> require('jsonfile').writeFileSync 'cache_labelsP.json', res, { spaces: 2 } ; res
#labelsP = Promise.resolve require('jsonfile').readFileSync 'cache_labelsP.json'

# Make sure we break if this is not set
totalIssuesOnTrello = 1000000
totalIssuesToCreate = 1000000
maxCards = 900

allCardsP = trello.getCardsOnBoard program.trelloBoard
.then (cards) -> labelsP.then (trelloLabels) -> inboxListIdP.then (inboxListId) ->
  totalIssuesOnTrello = cards.length
  trelloItems = []
  for card in cards
    # Clean and get card info
    number = textgen.numberFromDesc(program.githubUser, program.githubRepo)(card.desc)
    card.desc = textgen.normalize(card.desc)
    labels = (trelloLabels.idToName[idLabel] for idLabel in card.idLabels)
    trelloItems.push { number: number, card: card, labels: labels, inbox: (card.idList is inboxListId) } if number
  trelloItems
.map (trelloItem) ->
  trello.getCommentsOnCard trelloItem.card.id
  .map (comment) -> textgen.normalize(comment.data.text)
  .then (comments) ->
    trelloItem.comments = comments
    trelloItem
.then (res) -> require('jsonfile').writeFileSync 'cache_allCardsP.json', res, { spaces: 2 } ; res
#allCardsP = Promise.resolve require('jsonfile').readFileSync 'cache_allCardsP.json'

if program.includePullRequests
  openIssuesAndCommentsP = github.openIssuesAndCommentsAsync program.githubUser, program.githubRepo
else
  openIssuesAndCommentsP = github.openIssuesAndCommentsAsync program.githubUser, program.githubRepo, (issue) -> not issue.hasOwnProperty 'pull_request'
openIssuesAndCommentsP.tap (res) -> require('jsonfile').writeFileSync 'cache_openIssuesAndCommentsP.json', res, { spaces: 2 }
#openIssuesAndCommentsP = Promise.resolve require('jsonfile').readFileSync 'cache_openIssuesAndCommentsP.json'

fullDownloadP = Promise.resolve {}
.then (data) ->
  allCardsP.then (trelloItems) -> openIssuesAndCommentsP.then (githubItems) ->
    for trelloItem in trelloItems
      data[trelloItem.number] ?= { number: trelloItem.number }
      data[trelloItem.number].trello = trelloItem
    for githubItem in githubItems
      data[githubItem.issue.number] ?= { number: githubItem.issue.number }
      data[githubItem.issue.number].github = githubItem
  .then -> data
.then (data) ->
  Promise.resolve (number for number, info of data when info.trello and not info.github)
  .map (number) ->
    github.getIssueAndCommentsAsync program.githubUser, program.githubRepo, number
    .then (githubItem) ->
      data[number].github = githubItem
    .catch (e) ->
      console.log "ERROR GETTING ISSUE, marking as not found, received:", (JSON.stringify e, null, 2)
      if e.issueMoved is true
        data[number].github =
          issueMoved: true
          html_url: e.data.html_url
      else
        data[number].github = { issueNotFound: true }
  .then -> data
.then (data) -> (info for number, info of data)
.then (res) -> require('jsonfile').writeFileSync 'cache_fullDownloadP.json', res, { spaces: 2 } ; res
#fullDownloadP = Promise.resolve require('jsonfile').readFileSync 'cache_fullDownloadP.json'



checkIssuesP = fullDownloadP
.tap -> totalIssuesToCreate = 0
.tap (issues) -> console.log "Before filtering not found issues: #{issues.length}"
.filter (issue) -> !issue.github.issueNotFound
.tap (issues) -> console.log "After filtering not found issues: #{issues.length}"
.each (issue) ->
  if issue.github.issueMoved is true
    issue.newLabels = ['MOVED']
    issue.updateDesc = true
    issue.parsed =
      title: issue.trello.card.name
      desc: "MOVED TO: #{issue.github.html_url}, #{issue.trello.card.desc}"
    return
  issue.parsed = textgen.parseFullIssue(program.githubUser, program.githubRepo, keywords, program.warn)(issue.github)
  if issue.trello
    # Possible update
    issue.updateDesc = true if issue.trello.card.desc isnt issue.parsed.desc
    newComments = []
    for mention in issue.parsed.mentions when JSON.stringify(issue.trello.comments).indexOf(mention.html_url) < 0
      newComments.push mention.text
    newComments = [newComments.reverse().join '\n'] if newComments.length
    if program.fullText
      newComments = newComments.concat (comment for comment in issue.parsed.comments when comment not in issue.trello.comments)
    issue.newComments = newComments if newComments.length
    newLabels = (label for label in issue.parsed.labels when label not in issue.trello.labels)
    issue.newLabels = newLabels if newLabels.length
    # Possible closed and archive
    if issue.github.issue?.state is 'closed'
      if 'CLOSED' not in issue.trello.labels
        if issue.newLabels
          issue.newLabels.push 'CLOSED'
        else
          issue.newLabels = ['CLOSED']
      issue.archive = true if issue.trello.inbox
  else
    # New issue
    if issue.parsed.labels.length or not keywords.length
      issue.create = true
      totalIssuesToCreate++
.tap (issues) ->
  console.log ''
  console.log ''
  console.log "Total number of cards currently on Trello: #{totalIssuesOnTrello}"
  console.log "Number of cards to create now: #{totalIssuesToCreate}"
  if (totalIssuesOnTrello + totalIssuesToCreate) > maxCards
    console.log 'ERROR: Creating more issues will break the Trello API. A workaround must be found and implemented.'
  console.log ''
  console.log ''
  console.log '========== NEW ISSUES =========='
  for issue in issues when issue.create
    console.log "#{issue.parsed.title}"
  console.log ''
  console.log ''
  console.log '========== UPDATED ISSUES =========='
  for issue in issues when issue.updateDesc or issue.newComments or issue.newLabels
    console.log "#{issue.parsed.title}:"
    if issue.newComments
      console.log "  - New comments: #{issue.newComments.length}"
    if issue.newLabels
      console.log "  - New labels: #{issue.newLabels.join(' ')}"
    if issue.updateDesc
      console.log "  - Updated description:"
      console.log issue.parsed.desc.replace /^/mg, '      '
    console.log ''
  console.log ''
  console.log ''
  console.log '========== CLOSED INBOX ISSUES =========='
  for issue in issues when issue.archive
    console.log "#{issue.parsed.title}"
  console.log ''
  console.log ''



if program.commit
  queue = new PromiseQueue

  enqueueAddComments = (cardId, title, comments) ->
    queue.add ->
      Promise.reduce comments, (_, comment) ->
        console.log "Adding comment to issue \"#{title}\""
        #console.log "Adding comment to issue \"#{title}\": \"#{comment}\""
        trello.addCommentToCardAsync cardId, comment # Promise.reduce waits for returned promises
      , null
    return null

  checkIssuesP
  .tap (issues) ->
    queue.add ->
      Promise.reduce issues, (_, issue) ->
        if (totalIssuesOnTrello + totalIssuesToCreate) > maxCards
          console.log 'Creating more issues will break the Trello API. A workaround must be found and implemented.'
          return null
        else if issue.create
          inboxListIdP
          .then (inboxListId) ->
            console.log "Adding issue \"#{issue.parsed.title}\""
            trello.addCardAsync inboxListId, issue.parsed.title, issue.parsed.desc
          .tap (card) ->
            newComments = (mention.text for mention in issue.parsed.mentions)
            newComments = [newComments.reverse().join '\n'] if newComments.length
            if program.fullText
              newComments = newComments.concat issue.parsed.comments
            enqueueAddComments card.id, issue.parsed.title, newComments
            issue.parsed.labels.forEach (label) ->
              queue.add -> labelsP.then (trelloLabels) ->
                console.log "Adding label \"#{label}\" to issue \"#{issue.parsed.title}\""
                trello.addLabelToCardAsync card.id, trelloLabels.nameToId[label]
            return null
      , null
    return null
  .each (issue) ->
    if issue.updateDesc
      queue.add ->
        console.log "Updating description of issue \"#{issue.trello.card.name}\""
        trello.updateCardDescriptionAsync issue.trello.card.id, issue.parsed.desc
    if issue.newComments
      enqueueAddComments issue.trello.card.id, issue.parsed.title, issue.newComments
    if issue.newLabels
      issue.newLabels.forEach (newLabel) ->
        queue.add -> labelsP.then (trelloLabels) ->
          console.log "Adding new label \"#{newLabel}\" to issue \"#{issue.trello.card.name}\""
          trello.addLabelToCardAsync issue.trello.card.id, trelloLabels.nameToId[newLabel]
    if issue.archive and program.archiveFromInbox
      console.log "Archiving card \"#{issue.trello.card.name}\""
      trello.archiveCardAsync issue.trello.card.id
    return null
