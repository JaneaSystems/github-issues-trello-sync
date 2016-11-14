Promise = require 'bluebird'
Trello = require 'node-trello'



trello = null
trelloRateDelay = 200
delays = Promise.resolve()

exports.auth = (key, token) ->
  trello = new Trello key, token
  Promise.promisifyAll trello



apiCall = (log, ifunc, arg0, arg1 = {}, retriesLeft = 10) ->
  func = ifunc.bind trello
  delays = delays.delay trelloRateDelay
  delays.then ->
    console.log log
    if retriesLeft is 0
      console.log 'Exausted retries.'
      process.abort()
    func arg0, arg1
  .catch (e) ->
    console.log log
    if e.code is '504'
      console.log '504 error found, will retry'
      apiCall log, func, arg0, arg1, (retriesLeft - 1)
    else
      console.log e
      console.log e.stack
      process.abort()



# [{ id:'', desc:'', name:'', shortUrl:'' }]
exports.getCardsOnBoard = (boardId) ->
  apiCall "Downloading all cards on board #{boardId}...",
    trello.getAsync, '/1/boards/' + boardId + '/cards',
      limit: 1000
      fields: 'desc,name,shortUrl,idLabels,idList'

# [{ id:'', desc:'', name:'', shortUrl:'' }]
exports.getCardsOnList = (listId) ->
  apiCall "Downloading all cards on list #{listId}...",
    trello.getAsync, '/1/lists/' + listId + '/cards',
      limit: 1000
      fields: 'desc,name,shortUrl,idLabels,idList'

# [{ id:'', color:'', name:'' }]
exports.getLabelsOnBoard = (boardId) ->
  apiCall "Downloading all labels on board #{boardId}...",
    trello.getAsync, '/1/boards/' + boardId + '/labels',
      limit: 1000
      fields: 'color,name'

# [ { id:'', data:{ text:'' } } ]
exports.getCommentsOnCard = (cardId) ->
  apiCall "Downloading all comments on card #{cardId}...",
    trello.getAsync, '/1/cards/' + cardId + '/actions',
      filter: 'commentCard'
      fields: 'data,idMemberCreator'
      limit: 1000
      memberCreator: false

# @return [card]
exports.addCardAsync = (listId, title, desc = '') ->
  apiCall "Adding card \"#{title}\" to list #{listId}...",
    trello.postAsync, '/1/cards',
      name: title
      idList: listId
      desc: desc
      pos: 'top'

# @return [label]
exports.addLabelToBoardAsync = (boardId, name) ->
  apiCall "Adding label #{name} to board #{boardId}...",
    trello.postAsync, '/1/boards/' + boardId + '/labels',
      name: name
      color: 'red'

# @return [commentCard]
exports.addCommentToCardAsync = (cardId, comment) ->
  apiCall "Adding comment to card #{cardId}...",
    trello.postAsync, '/1/cards/' + cardId + '/actions/comments',
      text: comment

# @return [?]
exports.addLabelToCardAsync = (cardId, labelId) ->
  apiCall "Adding label to card #{cardId}...",
    trello.postAsync, '/1/cards/' + cardId + '/idLabels',
      value: labelId

# @return [card]
exports.updateCardDescriptionAsync = (cardId, desc) ->
  apiCall "Updating description of card #{cardId}...",
    trello.putAsync, '/1/cards/' + cardId + '/desc',
      value: desc

# @return [card]
exports.moveCardToListAsync = (cardId, listId, pos = 'top') ->
  apiCall "Moving card #{cardId} to list #{listId}...",
    trello.putAsync, '/1/cards/' + cardId + '/idList',
      value: listId
  .then () -> apiCall "Setting card #{cardId} to position #{pos}...",
    trello.putAsync, '/1/cards/' + cardId + '/pos',
      value: pos

# @return [?]
exports.archiveCardAsync = (cardId) ->
  apiCall "Archiving card #{cardId}...",
    trello.putAsync, '/1/cards/' + cardId + '/closed',
      value: true

# @return [list of lists]
exports.getListsOnBoardAsync = (boardId) ->
  apiCall "Downloading information about lists on board #{boardId}...",
    trello.getAsync, '/1/boards/' + boardId + '/lists'

###
# @return [list of cards]
exports.getCardsOnList = (listId) ->
  apiCall "Downloading all cards on list #{listId}...",
    trello.getAsync, '/1/lists/' + listId + '/cards'

# @return[card]
exports.getCard = (boardId, cardId) ->
  apiCall "Downloading card #{cardId} on board #{boardId}...",
    trello.getAsync, '/1/boards/' + boardId + '/cards/' + cardId
###

exports.deleteCommentAsync = (commentId) ->
  apiCall "Deletting comment #{commentId}...",
    trello.delAsync, '/1/actions/' + commentId


exports.findListIdAsync = (listName, boardId) ->
  exports.getListsOnBoardAsync boardId
  .filter (list) -> list.name is listName
  .then (lists) ->
    if lists.length > 0
      lists[0]
    else
      throw "Could not find list \"#{listName}\" on board \"#{boardId}\""
  .then (list) -> list.id
