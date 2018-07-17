exports.normalize = (s) ->
  s.replace(/\r\n/g, '\n')
   .replace(/\r/g, '\n')
   .replace(/<!--[\s\S]*?-->\n*/gm, '')
   .trim()

# truncateLength = 10000 # Avoid errors in trello
truncateLength = 800 # Avoid collapsing in trello

parseTitle = (issue, user, repo) ->
  type = if issue.hasOwnProperty 'pull_request' then 'PR' else 'I'
  #"[#{user}/#{repo}: \##{issue.number}] #{issue.title}"
  #"[#{repo}] #{issue.title} (\##{issue.number})"
  "[#{user}/#{repo}] #{issue.title} (#{type} \##{issue.number})"

parseDesc = (issue, user, repo) ->
  type = if issue.hasOwnProperty 'pull_request' then 'PR' else 'I'
  # The first line of description in trello is the identifier
  desc = "URL: #{issue.html_url}\n"
  # The second line is formatted to copy-paste to markdown
  cleantitle = issue.title.replace(/`/g, '\'')
  desc = desc + "`**[#{user}/#{repo}] #{cleantitle} ([#{type} \##{issue.number}](#{issue.html_url}))**  `\n"
  if issue.closed_by and issue.closed_at
    desc = desc + ":x: Issue closed by [#{issue.closed_by.login}](#{issue.closed_by.html_url}) on #{new Date(issue.closed_at).toDateString()}\n"
  desc = desc +
         "Created on: #{new Date(issue.created_at).toDateString()}\n" +
         "Created by: [#{issue.user.login}](#{issue.user.html_url})\n" +
         "Labels: #{(label.name for label in issue.labels).join(' ')}\n" +
         "\n" +
         "---\n" +
         exports.normalize(issue.body || "")
  if desc.length > truncateLength
    desc = desc[0...truncateLength] + "\n\n---\nTRUNCATED"
  desc.trim()

parseIssue = (issue, user, repo) ->
  title: parseTitle issue, user, repo
  desc: parseDesc issue, user, repo

parseComment = (comment) ->
  ret = ":octocat: [#{comment.user.login}](#{comment.user.html_url}) on #{new Date(comment.updated_at).toDateString()}\n" +
        "\n" +
        "---\n" +
        exports.normalize(comment.body)
  if ret.length > truncateLength
    ret = ret[0...truncateLength] + "\n\n---\nTRUNCATED"
  ret

parseComments = (comments) -> comments.map parseComment

parseLabels = (issue, labels) ->
  issueText = exports.normalize(JSON.stringify(issue))
    .replace('`vcbuild test nosign` (Windows)', '-')
    .replace('`vcbuild test` (Windows)', '-')
    .replace(/"node_id":"/g, '"-_id":"')
    .toUpperCase()
  label for label in labels when issueText.indexOf(label.toUpperCase()) > -1

parseMentions = (issue, labels) ->
  ret = []
  for comment in issue.comments
    commentText = JSON.stringify(comment).toUpperCase()
    mentions = (label for label in labels when commentText.indexOf(label.toUpperCase()) > -1)
    if mentions
      for mention in mentions
        unless comment.user.login is mention
          ret.push
            text: ":bangbang: #{mention} [was mentioned](#{comment.html_url}) by [#{comment.user.login}](#{comment.user.html_url}) on #{new Date(comment.updated_at).toDateString()}"
            mention: mention
            html_url: comment.html_url
            user:
              login: comment.user.login
              html_url: comment.user.html_url
  ret


exports.numberFromDesc = (user, repo) -> (desc) ->
  lines = desc.match /^.*$/m
  return null unless lines
  return null unless lines.length >= 1
  info = lines[0].match ///^
    URL:\ https://github.com/#{user}/#{repo}/.*/([0-9]+)
    $///i
  return null unless info
  parseInt(info[1])


exports.parseFullIssue = (user, repo, labels, warnKeywords) -> (issue) ->
  ret = parseIssue issue.issue, user, repo
  # Sanity check
  if issue.issue.number isnt exports.numberFromDesc(user, repo)(ret.desc)
    console.log '===== DESC ====='
    console.log ret.desc
    console.log '================'
    console.log issue.issue
    console.log '================'
    console.log user
    console.log repo
    console.log exports.numberFromDesc(user, repo)(ret.desc)
    console.log '================'
    throw "ERROR: Number can't be extracted from parsed description"
  ret.comments = parseComments issue.comments
  ret.labels = parseLabels issue, labels
  ret.mentions = parseMentions issue, warnKeywords
  ret
