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
  var wordWithoutPrefixes = bowlcut.RemovePrefixes(word)
  var wordWithoutPrefixesAndSuffixes = bowlcut.RemoveSuffixes(wordWithoutPrefixes)
  if len(word) == len(wordWithoutPrefixesAndSuffixes)
    return false
  endif
  # Make sure to exclude pb.go files from this search
  var numMatches = JumpToDefinition(wordWithoutPrefixesAndSuffixes)
  return numMatches > 0
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
  if USE_RIPGREP
    queryCmd = rg.RipgrepCommand(query, true)
  endif
  fzf#vim#grep(queryCmd, fzf#vim#with_preview(), false)
enddef

const MultipleMatchFunction = get(g:, "bowlcut_multiple_match_func", FzfFallback)

# This function jumps to a definition.
# If more than one definition is found for the given word to search, it will
# open up a fzf preview window for the user to select the one they would like
# to go to.
# This function returns a number indicating the number of matches it found.
# -1 indicates that there was an error.
def JumpToDefinition(wordToSearch: string): number
  const matches = GetMatches(wordToSearch)
  # If there is more than one result, we should let the user pick which one
  # they want to jump to. To do that, we will RE RUN (🤦) the ripgrep query
  # and open the results in a fzf preview window. I couldn't find a way to
  # open the preview window using already retrieved results.
  if len(matches) > 1
    # type 2 is a Funcref type
    if type(MultipleMatchFunction) == 2
      MultipleMatchFunction(bowlcut.Query(wordToSearch), matches)
      return len(matches)
    else
      echom "bowlcut: No multiple match function defined. Stopping."
    endif
    return -1
  endif
  if len(matches) == 0
    echom "bowlcut: No matches found. Stopping"
    return 0
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
  return 1
enddef
