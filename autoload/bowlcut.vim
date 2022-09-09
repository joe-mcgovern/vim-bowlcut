vim9script

# TODO: This file is a hodge-podge of various functions. It would be nice to
# split them up into more organized files.

const prefixes = get(g:, "bowlcut_prefixes", [])
const suffixes = get(g:, "bowlcut_suffixes", [])

def DefaultQuery(wordToSearch: string): string
  return shellescape('func \(.*\) ' .. wordToSearch .. '\(')
enddef

const QueryFunc = get(g:, "bowlcut_query_func", DefaultQuery)

export def Query(wordToSearch: string): string
  return QueryFunc(wordToSearch)
enddef

export def GetIncludedFilePatterns(): list<string>
  return get(g:, "bowlcut_include_files", [])
enddef

export def GetExcludedFilePatterns(): list<string>
  return get(g:, "bowlcut_exclude_files", [])
enddef

export def PathToProjectRoot(): string
  const path = expand("%:p:h")
  const parts = split(path, "/")
  const home = getenv("HOME")
  var currentIndex = len(parts) - 1
  while currentIndex >= 0
    const currentParts = parts[0 : currentIndex]
    const pathSubset = "/" .. join(currentParts, "/")
    if pathSubset ==# home
      break
    endif
    if isdirectory(pathSubset .. "/.git")
      return pathSubset
    endif
    currentIndex -= 1
  endwhile
  return ""
enddef

export def RemovePrefixes(input: string): string
  for prefix in prefixes
    if StartsWith(input, prefix)
      return substitute(input, "^" .. prefix, "", "")
    endif
  endfor
  return input
enddef

export def RemoveSuffixes(input: string): string
  for suffix in suffixes
    if EndsWith(input, suffix)
      return substitute(input, suffix .. "$", "", "")
    endif
  endfor
  return input
enddef

def StartsWith(str: string, prefix: string): bool
  return str[0 : len(prefix) - 1] ==# prefix
enddef

def EndsWith(str: string, suffix: string): bool
  return str[len(str) - len(suffix) : len(str) - 1] ==# suffix
enddef
