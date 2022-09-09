vim9script

import autoload 'bowlcut.vim'

const BASE_GREP_COMMAND = 'grep -E -R -H -n -o '

export def GrepCommand(query: string): string
  var grepCmd = BASE_GREP_COMMAND
  for include in bowlcut.GetIncludedFilePatterns()
    grepCmd = grepCmd .. ' --include ' .. shellescape(include)
  endfor
  for exclude in bowlcut.GetExcludedFilePatterns()
    grepCmd = grepCmd .. ' --exclude ' .. shellescape(exclude)
  endfor
  return grepCmd .. ' ' .. query .. ' ' .. bowlcut.PathToProjectRoot()
enddef

export def GetMatchesGrep(wordToSearch: string): list<dict<any>>
  const grepCmd = GrepCommand(bowlcut.Query(wordToSearch))
  const results = systemlist(grepCmd)
  var matches = []
  for result in results
    # Parse the grep result. It looks something like:
    # <filename>:<line number>:<text context>
    const pieces = split(result, ":")
    const filename = substitute(pieces[0], '^\.\/', '', '')
    const line = pieces[1]
    matches->add({filename: filename, line_number: str2nr(line), column_number: 0})
  endfor
  return matches
enddef
