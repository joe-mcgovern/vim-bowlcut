vim9script

import autoload 'bowlcut.vim'

const BASE_RIPGREP_COMMAND = 'rg --column --line-number --no-heading --smart-case '

export def RipgrepCommand(query: string): string
  var grepCmd = BASE_RIPGREP_COMMAND
  for include in bowlcut.GetIncludedFilePatterns()
    grepCmd = grepCmd .. ' --glob ' .. shellescape(include)
  endfor
  for exclude in bowlcut.GetExcludedFilePatterns()
    grepCmd = grepCmd .. ' --glob ' .. shellescape('!' .. exclude)
  endfor
  return grepCmd .. ' -- ' .. query .. ' ' .. bowlcut.PathToProjectRoot()
enddef

export def GetMatchesRipgrep(wordToSearch: string): list<dict<any>>
  const grepCmd = RipgrepCommand(bowlcut.Query(wordToSearch))
  const results = systemlist(grepCmd)
  var matches = []
  for result in results
    # Parse the ripgrep result. It looks something like:
    # <filename>:<line number>:<column number>:<text context>
    const pieces = split(result, ":")
    const filename = pieces[0]
    const line = pieces[1]
    const column = pieces[2]
    matches->add({filename: filename, line_number: str2nr(line), column_number: str2nr(column)})
  endfor
  return matches
enddef
