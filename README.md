# github-issues-trello-sync

```
  Usage: app -u <github-user> -r <github-repo> [-g github-token] -k <trello-key> -t <trello-token> -b <trello-board> [KEYWORDS...]

  Options:

    -h, --help                  output usage information
    -V, --version               output the version number
    -u, --github-user <user>    Github user or organization hosting the repository
    -r, --github-repo <repo>    Github repository name
    -g, --github-token <repo>   optional Github OAuth2 token
    -k, --trello-key <key>      Trello key
    -t, --trello-token <token>  Trello auth token
    -b, --trello-board <id>     Trello board ID (list for now)
    -n, --no-commit             Download and calculate modifications but do not write them to Trello
```

The repository where to get the issues is specified with `-u` and `-r`.

The GitHub token is needed to access private repositories or repositories with more than a few issues.

The Trello key and token are always needed.

The Trello board id is the id in the board link.

Keywords are what to search for to decide if a new issue should be imported. A label for each keyword will be created in trello.

Example call:

```
node github-issues-trello-sync/app.js -u org -r repo -g ?? -k ?? -t ?? -b ?? search1 search2
```

## Trello Key

https://trello.com/1/appKey/generate

## Trello Token

Use the key from above in:

https://trello.com/1/authorize?key=___SUBSTITUTE_WITH_YOUR_KEY___&name=Issue+Importer+Prototype&response_type=token&scope=read,write

This will be valid for 30 days, but you can revoke it at https://trello.com/my/account

## Github Token

https://github.com/settings/tokens
