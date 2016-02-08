exports.normalize = (s) -> s.replace(/\r\n/g, '\n').replace(/\r/g, '\n')

parseTitle = (issue, user, repo) ->
  #"[#{user}/#{repo}: \##{issue.number}] #{issue.title}"
  #"[#{repo}] #{issue.title} (\##{issue.number})"
  "[#{user}/#{repo}] #{issue.title} (\##{issue.number})"

parseDesc = (issue) ->
  # The first line of description in trello is the identifier
  desc = 'URL: ' + issue.html_url
  if issue.state isnt 'open'
    desc = desc + '\n' +
           ":x: Issue closed by [#{issue.closed_by.login}](#{issue.closed_by.html_url}) on #{new Date(issue.closed_at).toDateString()}"
  desc = desc + '\n' +
         "Created on: #{new Date(issue.created_at).toDateString()}\n" +
         "Created by: [#{issue.user.login}](#{issue.user.html_url})\n" +
         "Labels: #{(label.name for label in issue.labels).join(' ')}\n" +
         "\n" +
         "---\n" +
         exports.normalize(issue.body)
  if desc.length > 10000
    desc = desc[0...10000] + "\n\n---\nTRUNCATED"
  desc

parseIssue = (issue, user, repo) ->
  title: parseTitle issue, user, repo
  desc: parseDesc issue

parseComment = (comment) ->
  ret = ":octocat: [#{comment.user.login}](#{comment.user.html_url}) on #{new Date(comment.updated_at).toDateString()}\n" +
        "\n" +
        "---\n" +
        exports.normalize(comment.body)
  if ret.length > 10000
    ret = ret[0...10000] + "\n\n---\nTRUNCATED"
  ret

parseComments = (comments) -> comments.map parseComment

parseLabels = (issue, labels) ->
  issueText = JSON.stringify(issue).toUpperCase()
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
    $///
  return null unless info
  parseInt(info[1])


exports.parseFullIssue = (user, repo, labels, warnKeywords) -> (issue) ->
  ret = parseIssue issue.issue, user, repo
  # Sanity check
  if issue.issue.number isnt exports.numberFromDesc(user, repo)(ret.desc)
    console.log '===== DESC ====='
    console.log ret.desc
    console.log '================'
    throw "ERROR: Number can't be extracted from parsed description"
  ret.comments = parseComments issue.comments
  ret.labels = parseLabels issue, labels
  ret.mentions = parseMentions issue, warnKeywords
  ret  
