vim9script

if exists("g:autoloaded_pbgo")
  finish
endif

g:autoloaded_pbgo = 1

# Your query string is appended to this string. Make sure to shellescape() your
# string first
const BASE_GREP_COMMAND = 'rg --column --line-number --no-heading --smart-case --type-add "goproto:*.{pb.go}" --type-not goproto -- '

def g:SmartGoToDefinitionGolang()
  const result = g:JumpToTemporalDefinitionUnderCursor()
  if result
      return
  endif
  ale#definition#GoToCommandHandler()
enddef

def g:JumpToTemporalDefinitionUnderCursor(): bool
  if &ft != "go"
    return false
  endif
  const word = expand("<cword>")
  var wordToSearch = word
  const prefixes = ["ExecuteActivity", "ExecuteWorkflow", "ExecuteChildWorkflow"]
  for prefix in prefixes
    if StartsWith(word, prefix)
      wordToSearch = substitute(word, "^" .. prefix, "", "")
      break
    endif
  endfor
  if len(word) == len(wordToSearch)
    return false
  endif
  const suffixes = ["Async"]
  for suffix in suffixes
    if EndsWith(wordToSearch, suffix)
      wordToSearch = substitute(wordToSearch, suffix .. "$", "", "")
    endif
  endfor
  # Make sure to exclude pb.go files from this search
  JumpToTemporalDefinition(wordToSearch)
  return true
enddef

# This function jumps to a temporal definition.
# If more than one definition is found for the given word to search, it will
# open up a fzf preview window for the user to select the one they would like
# to go to.
def JumpToTemporalDefinition(wordToSearch: string)
  const query = 'func \(.*\) ' .. wordToSearch .. '\('
  # The --type-add stuff is here so that we can ignore pb.go files
  const grep_cmd = BASE_GREP_COMMAND .. shellescape(query)
  const results = systemlist(grep_cmd)
  # If there is more than one result, we should let the user pick which one
  # they want to jump to. To do that, we will RE RUN (🤦) the ripgrep query
  # and open the results in a fzf preview window. I couldn't find a way to
  # open the preview window using already retrieved results.
  if len(results) > 1
    TemporalFzfFunctionQuery(query, 0)
    return
  endif
  # Parse the ripgrep result. It looks something like:
  # <filename>:<line number>:<column number>:<text context>
  const result = results[0]
  const pieces = split(result, ":")
  const filename = pieces[0]
  const line = pieces[1]
  const column = pieces[2]
  const bufnum = bufadd(filename)
  bufload(bufnum)
  # Ordering is important here. Setting the position before opening the buffer
  # was resulting in some weird behavior.
  execute "buffer " .. bufnum
  setpos(".", [bufnum, str2nr(line), str2nr(column), 0])
  # I know this is hacky, but it will jump from the start of the line to the
  # beginning of the function name
  execute "normal! WWW"
enddef

# This function performs a typical fzf query, ignoring pb.go files
def TemporalFzfFunctionQuery(query: string, fullscreen: bool)
  const command_fmt = BASE_GREP_COMMAND .. shellescape(query) .. ' || true'
  const initial_command = printf(command_fmt, shellescape(query))
  const reload_command = printf(command_fmt, '{q}')
  const spec = {'options': ['--phony', '--query', query, '--bind', 'change:reload:' .. reload_command]}
  fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), fullscreen)
enddef

def StartsWith(str: string, prefix: string): bool
  return str[0 : len(prefix) - 1] ==# prefix
enddef

def EndsWith(str: string, suffix: string): bool
  return str[len(str) - len(suffix) : len(str) - 1] ==# suffix
enddef
