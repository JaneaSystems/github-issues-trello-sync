Promise = require 'bluebird'
Trello = require 'node-trello'



trello = null
trelloRateDelay = 200
delays = Promise.resolve()

exports.auth = (key, token) ->
  trello = new Trello key, token
  Promise.promisifyAll trello



# [{ id:'', desc:'', name:'', shortUrl:'' }]
exports.getCardsOnBoard = (boardId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    console.log "Downloading all cards on board #{boardId}..."
    trello.getAsync '/1/boards/' + boardId + '/cards',
      limit: 1000
      fields: 'desc,name,shortUrl,idLabels'

# [{ id:'', color:'', name:'' }]
exports.getLabelsOnBoard = (boardId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    console.log "Downloading all labels on board #{boardId}..."
    trello.getAsync '/1/boards/' + boardId + '/labels',
      limit: 1000
      fields: 'color,name'

# [ { id:'', data:{ text:'' } } ]
exports.getCommentsOnCard = (cardId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    console.log "Downloading all comments on card #{cardId}..."
    trello.getAsync '/1/cards/' + cardId + '/actions',
      filter: 'commentCard'
      fields: 'data,idMemberCreator'
      limit: 1000
      memberCreator: false

# @return [card]
exports.addCardAsync = (listId, title, desc = '') ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    #console.log "Adding card \"#{title}\" to list #{listId}..."
    trello.postAsync '/1/cards',
      name: title
      idList: listId
      desc: desc
      pos: 'top'

# @return [label]
exports.addLabelToBoardAsync = (boardId, name) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    #console.log "Adding label #{name} to board #{boardId}..."
    trello.postAsync '/1/boards/' + boardId + '/labels',
      name: name
      color: 'red'

# @return [commentCard]
exports.addCommentToCardAsync = (cardId, comment) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    #console.log "Adding comment to card #{cardId}..."
    trello.postAsync '/1/cards/' + cardId + '/actions/comments',
      text: comment

# @return [?]
exports.addLabelToCardAsync = (cardId, labelId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    #console.log "Adding label to card #{cardId}..."
    trello.postAsync '/1/cards/' + cardId + '/idLabels',
      value: labelId

# @return [card]
exports.updateCardDescriptionAsync = (cardId, desc) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    #console.log "Updating description of card #{cardId}..."
    trello.putAsync '/1/cards/' + cardId + '/desc',
      value: desc

# @return [list of lists]
exports.getListsOnBoardAsync = (boardId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    console.log "Downloading information about lists on board #{boardId}..."
    trello.getAsync '/1/boards/' + boardId + '/lists'

###
# @return [list of cards]
exports.getCardsOnList = (listId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    console.log "Downloading all cards on list #{listId}..."
    trello.getAsync '/1/lists/' + listId + '/cards'

# @return[card]
exports.getCard = (boardId, cardId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    console.log "Downloading card #{cardId} on board #{boardId}..."
    trello.getAsync '/1/boards/' + boardId + '/cards/' + cardId
###

exports.deleteCommentAsync = (commentId) ->
  delays = delays.delay(trelloRateDelay)
  delays.then -> 
    console.log "Deletting comment #{commentId}..."
    trello.delAsync '/1/actions/' + commentId


exports.findListIdAsync = (listName, boardId) ->
  exports.getListsOnBoardAsync boardId
  .filter (list) -> list.name is listName
  .then (lists) ->
    if lists.length > 0
      lists[0]
    else
      throw "Could not find list \"#{listName}\" on board \"#{boardId}\""
  .then (list) -> list.id
