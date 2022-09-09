vim9script

import autoload 'bowlcut.vim'
import autoload 'rg.vim'
import autoload 'grep.vim'

if exists("g:loaded_bowlcut")
  finish
endif

g:loaded_bowlcut = 1

command! -nargs=0 BowlcutJump :call g:BowlcutJumpToDefinition()
command! -nargs=0 BowlcutJumpALE :call g:BowlcutJumpToDefinitionWithALEFallback()

def g:BowlcutJumpToDefinitionWithALEFallback()
  const result = g:BowlcutJumpToDefinition()
  if result
      return
  endif
  ale#definition#GoTo({})
enddef

def g:BowlcutJumpToDefinition(): bool
  const word = expand("<cword>")
  var wordToSearch = bowlcut.RemovePrefixes(word)
  if len(word) == len(wordToSearch)
    return false
  endif
  wordToSearch = bowlcut.RemoveSuffixes(wordToSearch)
  # Make sure to exclude pb.go files from this search
  JumpToDefinition(wordToSearch)
  return true
enddef

const USE_GREP = get(g:, "bowlcut_use_grep", 1)
const USE_RIPGREP = get(g:, "bowlcut_use_ripgrep", 0)
var DefaultGetMatchesFunc = grep.GetMatchesGrep
if USE_RIPGREP
  DefaultGetMatchesFunc = rg.GetMatchesRipgrep
endif
const GetMatches = get(g:, "bowlcut_match_func", DefaultGetMatchesFunc)

# This function performs a typical fzf query
def FzfFallback(query: string, matches: list<dict<any>>)
  var queryCmd = grep.GrepCommand(query)
  var reloadCommand = grep.GrepCommand(shellescape('{q}'))
  if USE_RIPGREP
    queryCmd = rg.RipgrepCommand(query)
    reloadCommand = rg.RipgrepCommand(shellescape('{q}'))
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
      MultipleMatchFunction(bowlcut.Query(wordToSearch), matches)
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
