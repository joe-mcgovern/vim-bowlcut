# bowlcut.vim

## Motivation

This project was created because of a problem I had been running into at work.
A service would define a function like `FetchResource`. We would then generate 
some code for clients to interact with this service, but the definitions the
clients use would be something like `ExecuteWorkflowFetchResource`. In practice, 
the actual definition of `ExecuteWorkflowFetchResource` is essentially worthless 
(because it is auto-generated); I'm usually interested in seeing the implementation
of `FetchResource`. 

To get to this definition, I would copy the non-generated portion of the function
name (`FetchResource`) and then type in a query: `func \(.*\) FetchResource`. 
Doing this many times a day became a cumbersome annoyance that this plugin aims
to solve. Given a list of prefixes and suffixes produced by auto-generated code, 
this plugin can determine if the word under cursor should be stripped of those
prefixes & suffixes, and then jump to the *stripped* word. 

This project was built with golang in mind. Thus, the default query searches
for a golang function.

I built this project to solve a problem I was facing, but if others find the concept
useful, I would consider adding features so that other languages could be compatible.

## Dependencies

⚠️ This plugin is written in vim9script. Make sure you have at least vim9 installed
before using this.

⚠️ This plugin has a default dependency on fzf, but it can easily be disabled (see
[Disabling FZF dependency](#disabling-fzf-dependency)).

## Installation

Install using your favorite package manager, or use Vim's built-in package support:

```
mkdir -p ~/.vim/pack/plugin/start
cd ~/.vim/pack/plugin/start
git clone https://github.com/joe-mcgovern/vim-bowlcut.git
vim -u NONE -c "helptags bowlcut/doc" -c q
```

## Usage

This plugin provides two commands to jump to the correct definition under the cursor.
They are:

`BowlcutJump`
`BowlcutJumpALE`

The first removes the globally defined prefixes and suffixes, and then greps for the
word under cursor. If it finds a single match, it will jump to that definition 
and return true. If it finds no matches, it will do nothing and return false. If
it finds multiple matches, it will call the function defined in the global variable
`g:bowlcut_multiple_match_func`, which defaults to a function that opens the results
in a fzf preview window, and then return true.

The `BowlcutJumpALE` does the same thing as  `BowlcutJump`
except that it if not results are found, it will fallback on the `ALEGoToDefinition`
function to jump to the ENTIRE definition under cursor (including defined prefixes
and suffixes).

Only one prefix will be removed. Once a match is found, no more prefixes are
considered. Suffixes are not removed if no prefix is removed (e.g. a prefix
must be removed in order to remove a suffix).

Here is my configuration:

```vim
let g:bowlcut_use_ripgrep = 1
let g:bowlcut_prefixes = ["ExecuteActivity", "ExecuteWorkflow", "ExecuteChildWorkflow"]
let g:bowlcut_suffixes = ["Async"]
let g:bowlcut_include_files = ["*.go"]
let g:bowlcut_exclude_files = ["*.pb.go"]
augroup golang_jump
  autocmd!
  autocmd FileType go nnoremap <buffer> <C-]> :BowlcutJumpALE<CR>
augroup END
```

My dependencies for this setup are [ale](https://github.com/dense-analysis/ale) (my lsp manager), 
[fzf](https://github.com/junegunn/fzf.vim) (my fuzzy finder) and [ripgrep](https://github.com/BurntSushi/ripgrep) 
(the flavor of fuzzy finder I like to use).

## Configuration 

### Disabling FZF dependency

If you do not want the dependency on fzf, you can either define your own multiple
match function, or set it to 0: `let g:bowlcut_multiple_match_func = 0`.

### Using ripgrep

By default, `grep` will be used to do the searching. If you would like to use
[ripgrep](https://github.com/BurntSushi/ripgrep), you can set 
`let g:bowlcut_use_ripgrep = 1` in your .vimrc.

### Modifying prefixes & suffixes

You can override the prefixes and suffixes that this plugin will replace when
attempting to strip the word under cursor. To do this, set the following
variables:

```
let g:bowlcut_prefixes = ['prefix1', 'prefix2']
let g:bowlcut_suffixes = ['suffix1', 'suffix2']
```

### Providing your own matching function

If you want to use a different grep mechanism, you provide your own matching
function by setting the `g:bowlcut_match_func` variable. This function takes in
a string, which is the *stripped* word under cursor (meaning the prefixes
and suffixes have been removed). It MUST return a list of dictionaries that
contain the following keys & values: `filename`, `line_number`, and `column_number`.
`line_number` and `column_number` MUST be numbers (which can be accomplished
using the `str2nr(in_string)` function).

### Providing your own query function

You also may override the default query function by setting the `g:bowlcut_query_func`
variable. This function takes in a string and outputs a string. The input string
is the *stripped* word under cursor (meaning prefixes and suffixes have
been removed). The string it returns should be a regex pattern that will be
provided to the grep tool.
