vim9script

if exists("g:autoloaded_bowlcut")
  finish
endif

g:autoloaded_bowlcut = 1

command! -nargs=0 BowlcutJump :call g:BowlcutJumpToDefinition()
command! -nargs=0 BowlcutJumpALE :call g:BowlcutJumpToDefinitionWithALEFallback()

const prefixes = get(g:, "bowlcut_prefixes", [])
const suffixes = get(g:, "bowlcut_suffixes", [])
const include_file_pattern = get(g:, "bowlcut_include_files", "")
const exclude_file_pattern = get(g:, "bowlcut_exclude_files", "")

# Your query string is appended to this string. Make sure to shellescape() your
# string first
const BASE_GREP_COMMAND = 'grep -E -R -H -n -o '
const BASE_RIPGREP_COMMAND = 'rg --column --line-number --no-heading --smart-case '

def g:BowlcutJumpToDefinitionWithALEFallback()
  const result = g:BowlcutJumpToDefinition()
  if result
      return
  endif
  ale#definition#GoToCommandHandler()
enddef

def g:BowlcutJumpToDefinition(): bool
  const word = expand("<cword>")
  var wordToSearch = RemovePrefixes(word)
  if len(word) == len(wordToSearch)
    return false
  endif
  wordToSearch = RemoveSuffixes(wordToSearch)
  # Make sure to exclude pb.go files from this search
  JumpToDefinition(wordToSearch)
  return true
enddef

def RemovePrefixes(input: string): string
  for prefix in prefixes
    if StartsWith(input, prefix)
      return substitute(input, "^" .. prefix, "", "")
    endif
  endfor
  return input
enddef

def RemoveSuffixes(input: string): string
  for suffix in suffixes
    if EndsWith(input, suffix)
      return substitute(input, suffix .. "$", "", "")
    endif
  endfor
  return input
enddef

def DefaultQuery(wordToSearch: string): string
  return shellescape('func \(.*\) ' .. wordToSearch .. '\(')
enddef

const Query = get(g:, "bowlcut_query_func", DefaultQuery)

def GrepCommand(query: string): string
  var grepCmd = BASE_GREP_COMMAND
  for include in include_file_pattern
    grepCmd = grepCmd .. ' --include ' .. shellescape(include)
  endfor
  for exclude in exclude_file_pattern
    grepCmd = grepCmd .. ' --exclude ' .. shellescape(exclude)
  endfor
  return grepCmd .. ' ' .. query .. ' .'
enddef

def GetMatchesGrep(wordToSearch: string): list<dict<any>>
  const grepCmd = GrepCommand(Query(wordToSearch))
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

def RipgrepCommand(query: string): string
  var grepCmd = BASE_RIPGREP_COMMAND
  for include in include_file_pattern
    grepCmd = grepCmd .. ' --glob ' .. shellescape(include)
  endfor
  for exclude in exclude_file_pattern
    grepCmd = grepCmd .. ' --glob ' .. shellescape('!' .. exclude)
  endfor
  return grepCmd .. ' -- ' .. query
enddef

def GetMatchesRipgrep(wordToSearch: string): list<dict<any>>
  const grepCmd = RipgrepCommand(Query(wordToSearch))
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

const USE_GREP = get(g:, "bowlcut_use_grep", 1)
const USE_RIPGREP = get(g:, "bowlcut_use_ripgrep", 0)
var DefaultGetMatchesFunc = GetMatchesGrep
if USE_RIPGREP
  DefaultGetMatchesFunc = GetMatchesRipgrep
endif
const GetMatches = get(g:, "bowlcut_match_func", DefaultGetMatchesFunc)

# This function performs a typical fzf query
def FzfFallback(query: string, matches: list<dict<any>>)
  var queryCmd = GrepCommand(query)
  var reloadCommand = GrepCommand(shellescape('{q}'))
  if USE_RIPGREP
    queryCmd = RipgrepCommand(query)
    reloadCommand = RipgrepCommand(shellescape('{q}'))
  endif
  queryCmd = queryCmd .. ' || true'
  reloadCommand = reloadCommand .. ' || true'
  echom queryCmd
  echom reloadCommand
  const spec = {'options': ['--phony', '--query', query, '--bind', 'change:reload:' .. reloadCommand]}
  fzf#vim#grep(queryCmd, 1, fzf#vim#with_preview(spec), 0)
enddef

const MultipleMatchFunction = get(g:, "bowlcut_multiple_match_func", FzfFallback)

# This function jumps to a definition.
# If more than one definition is found for the given word to search, it will
# open up a fzf preview window for the user to select the one they would like
# to go to.
def JumpToDefinition(wordToSearch: string)
  const matches = GetMatches(wordToSearch)
  # If there is more than one result, we should let the user pick which one
  # they want to jump to. To do that, we will RE RUN (🤦) the ripgrep query
  # and open the results in a fzf preview window. I couldn't find a way to
  # open the preview window using already retrieved results.
  if len(matches) > 1
    echom MultipleMatchFunction
    if type(MultipleMatchFunction) == 2
      MultipleMatchFunction(Query(wordToSearch), matches)
    else
      echom "bowlcut: No multiple match function defined. Stopping."
    endif
    return
  endif
  const firstMatch = matches[0]
  const bufnum = bufadd(firstMatch.filename)
  bufload(bufnum)
  # Ordering is important here. Setting the position before opening the buffer
  # was resulting in some weird behavior.
  execute "buffer " .. bufnum
  setpos(".", [bufnum, firstMatch.line_number, firstMatch.column_number, 0])
  # Move the cursor to the word we are searching for
  search(wordToSearch)
enddef

def StartsWith(str: string, prefix: string): bool
  return str[0 : len(prefix) - 1] ==# prefix
enddef

def EndsWith(str: string, suffix: string): bool
  return str[len(str) - len(suffix) : len(str) - 1] ==# suffix
enddef
