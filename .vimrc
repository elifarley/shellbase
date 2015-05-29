" Tips:
" https://www.cs.oberlin.edu/~kuperman/help/vim/home.html
" http://vim.wikia.com/wiki/Mapping_keys_in_Vim_-_Tutorial_(Part_1)
" http://dougblack.io/words/a-good-vimrc.html
" scrooloose's vim configuraiton: https://github.com/scrooloose/vimfiles
" http://vim.wikia.com/wiki/Example_vimrc
" http://nvie.com/posts/how-i-boosted-my-vim/
" https://news.ycombinator.com/item?id=856051
" http://dougireton.com/blog/2013/02/23/layout-your-vimrc-like-a-boss/
" https://wiki.archlinux.org/index.php/Vim#See_also
" Vim cheat sheet: http://www.viemu.com/vi-vim-cheat-sheet.gif
" Vim movement cmds image: http://qph.is.quoracdn.net/main-qimg-6c3f7b7470cf8dc55fa4eaeab8a876ff

" --

" <Esc> alternatives: <CTRL>-[ and <CTRL>-C and <ALT>-<ENTER>
" and <ALT>-<SPACE> or use <ALT>-<normal mode key>
" See http://vim.wikia.com/wiki/Avoid_the_escape_key

" Use {count}<CTRL>-^ to edit buffer {count}
" and <CTRL>-^ to edit last edited file
" (or <F10> or <SPACE>-0 to choose what buffer to edit)

" <CTRL>-I and <CTRL>-o to navigate visited places, even in closed buffers
" or from the last time you opened vim.
" (Ex.: open vim and type <C-o> to open last file)
" http://vim.wikia.com/wiki/Using_marks:
" Type ' twice to jump back to line or ( ` twice = pos in line ) 
" `. to jump to last change; `0	jump to pos in last file edited (when exited Vim)
" <CTRL>-E / <CTRL>-D and <CTRL>-Y / <CTRL>-U to scroll up or down

" Normal mode:
" "{register}{yd} -> yank or delete text to {register}

" Insert mode:
" <C-W> del prev word. <C-U> del all chars before cursor
" <C-T> indent one shiftwidth (Tabs). <C-D> remove one shiftwidth (Detabs)
" <C-R>{register} paste {register}'s contents
" <C-P>, <C-N> word completion, like content assist
" <C-o> perform a single NormalMode command

" [range]:g//[cmd] executes [cmd] for every match.
" g/^#/d Delete all lines that begins with #
" g/^$/d Delete all lines that are empty

" 5,8s/xxx/yyy/gc -> search and replace all occurrences of xxx in lines 5 to 8 with confirmation

" ----------

" Use Vim settings, rather than Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" See http://vim.wikia.com/wiki/Mapping_fast_keycodes_in_terminal_Vim
" More at http://mg.pov.lt/vim/vimrc
set <S-F1>=^[[1;2P
set <S-F2>=^[[1;2Q
set <S-F3>=^[[1;2R
set <S-F4>=^[[1;2S
set <S-F5>=^[[15;2~
set <S-F6>=^[[17;2~
set <S-F7>=^[[18;2~
set <S-F8>=^[[19;2~
set <S-F9>=^[[20;2~
set <S-F10>=^[[21;2~
set <S-F11>=^[[23;2~
set <S-F12>=^[[24;2~

set shortmess+=I                " hide the launch screen

set t_Co=256 " enable colorscheme
" Please add 'term screen-256color' to ~/.screenrc

" https://raw.githubusercontent.com/sjl/badwolf/master/colors/badwolf.vim
" save it to ~/.vim/colors/badwolf.vim
if !empty(glob("$HOME/.vim/colors/badwolf.vim"))
  let g:badwolf_darkgutter = 1
  let g:badwolf_css_props_highlight = 1
  "colorscheme badwolf
endif

" https://raw.githubusercontent.com/jnurmine/Zenburn/master/colors/zenburn.vim
if !empty(glob("$HOME/.vim/colors/zenburn.vim"))
  let g:zenburn_alternate_Visual = 1 " More contrast in Visual Selection
  let g:zenburn_unified_CursorColumn = 1
  "let g:zenburn_high_Contrast = 1
  colorscheme zenburn
endif

if v:version >= 703
  " Undo settings
  set undodir=~/.vim/undofiles
  set undofile

  set colorcolumn=+1 " Mark the ideal max text width
endif

" http://vim.wikia.com/wiki/Project_browsing_using_find
" then you can type :find <full-file-name-including-extension>
set path=$PWD/**

" See also: http://vim.wikia.com/wiki/Find_in_files_within_Vim

" http://vim.wikia.com/wiki/To_switch_back_to_normal_mode_automatically_after_inaction
" Automatically leave insert mode after 'updatetime' milliseconds of inaction
au CursorHoldI * stopinsert
" Set 'updatetime' to 15 seconds when in insert mode
au InsertEnter * let updaterestore=&updatetime | set updatetime=15000
au InsertLeave * let &updatetime=updaterestore

set autoread        " Automatically reload files changed outside of Vim

set tabstop=2       " Number of visual spaces per TAB
set softtabstop=2   " Number of spaces in tab when editing
set shiftwidth=2   " Used when indenting with >> and <<
set shiftround      " Use multiple of shiftwidth when indenting with '<' and '>'
set expandtab       " Tabs are spaces
set smarttab        " Insert tabs on the start of a line according to shiftwidth, not tabstop
set copyindent      " copy the previous indentation on autoindenting

" Quickly time out on keycodes
set ttimeout ttimeoutlen=200

set backspace=indent,eol,start " allow backspacing over everything in insert mode

set history=1000 " Store lots of :cmdline history
set undolevels=1000 " Use many muchos levels of undo

set title              " change the terminal's title
set number             " Show line numbers
set showcmd             " Show incomplete cmds down the bottom
" Set the command window height to 2 lines, to avoid many cases of having to
" press <Enter> to continue"
set cmdheight=2
set showmode            " Show current mode down the bottom
set cursorline          " Highlight current line
set cursorcolumn        " Highlight current column

set formatoptions-=o "dont continue comments when pushing o/O

" Vertical/horizontal scroll off settings
set scrolloff=3
set sidescrolloff=7
set sidescroll=1

" Enable mouse. To copy to OS clipboard, keep <SHIFT> pressed
set mouse=a
set ttymouse=xterm2

set hidden " so that buffers with unsaved changes can be hidden

set wildmenu                " Enable ctrl-n and ctrl-p to scroll thru matches
"set wildmode=list:longest   " make cmdline tab completion similar to bash
set wildmode=list:longest,full " better
set wildignore=*.o,*.obj,*~,*.swp,*.bak,*.pyc,*.class " Stuff to ignore when tab completing

set wildcharm=<C-Z>

let mapleader=" "       " Leader is space

" http://unix.stackexchange.com/a/186558/46796
nno : ;
nno ; :
vno : ;
vno ; :

" Good for Brazillian ABNT2 keyboards
nno ç :

" qq to start recording macro, then q to stop; Q to play back
nnoremap Q @q

filetype plugin indent on       " enable detection, plugins and indenting in one step
syntax on " Turn on syntax highlighting

" Highlight whitespaces and mark lines that extend off-screen
set list
set listchars=tab:▸\ ,trail:·,extends:>,precedes:<,nbsp:·,eol:¬

" No whitespaces shown for these filetypes:
autocmd filetype html,xml set listchars-=tab:>.

" Highlight trailing whitespace
hi TrailingSpace ctermbg=DarkGrey
au filetype c,cpp,python match TrailingSpace "\s\+\n"

set showmatch           " Highlight matching [{()}]. Type % to go to it
" Highlight last inserted text
nnoremap gV `[v`]

hi Visual term=reverse cterm=reverse ctermfg=White

" http://alvinalexander.com/linux/vi-vim-editor-color-scheme-syntax
" Color table: https://github.com/guns/xterm-color-table.vim
highlight Search ctermfg=White ctermbg=103
set hlsearch            " Highlight matches
set incsearch           " Search as characters are entered
set ignorecase smartcase " lowercase-only search terms will match uppercase text too
nnoremap / /\v
vnoremap / /\v
set gdefault " applies substitutions globally on lines

" http://vim.wikia.com/wiki/Searching
" Apply smartcase to current word searches
:nnoremap * /\<<C-R>=expand('<cword>')<CR>\><CR>
:nnoremap # ?\<<C-R>=expand('<cword>')<CR>\><CR>

" http://vim.wikia.com/wiki/VimTip14
" Press <ENTER> to highlight current word without moving
let g:highlighting = 0
function! Highlighting()
  if g:highlighting == 1 && @/ =~ '^\\<'.expand('<cword>').'\\>$'
    let g:highlighting = 0
    return ":silent nohlsearch\<CR>"
  endif
  let @/ = '\<'.expand('<cword>').'\>'
  let g:highlighting = 1
  return ":silent set hlsearch\<CR>"
endfunction
nnoremap <silent> <expr> <CR> Highlighting()

" http://vim.wikia.com/wiki/VimTip528
" {{ Make search results appear in the middle of the screen
nnoremap <silent> <Leader>/ :call <SID>SearchMode()<CR>
function s:SearchMode()
  if !exists('s:searchmode') || s:searchmode == 0
    echo 'Search next: scroll hit to middle if not on same page'
    nnoremap <silent> n n:call <SID>MaybeMiddle()<CR>
    nnoremap <silent> N N:call <SID>MaybeMiddle()<CR>
    let s:searchmode = 1
  elseif s:searchmode == 1
    echo 'Search next: scroll hit to middle'
    nnoremap n nzz
    nnoremap N Nzz
    let s:searchmode = 2
  else
    echo 'Search next: normal'
    nunmap n
    nunmap N
    let s:searchmode = 0
  endif
endfunction

" If cursor is in first or last line of window, scroll to middle line.
function s:MaybeMiddle()
  if winline() == 1 || winline() == winheight(0)
    normal! zz
  endif
endfunction
" }}

" Toggle search-highlighting
"nnoremap <silent> <C-l> :setlocal hlsearch!<CR>
" Map <C-L> (redraw screen) to also turn off search highlighting until the next search
nnoremap <C-L> :nohl<CR><C-L>

" Toggle line numbers and special chars for each window
nnoremap <C-N><C-N> :setlocal number!<BAR>setlocal list!<CR>

" http://vim.wikia.com/wiki/Toggle_auto-indenting_for_code_paste
set paste " Start with paste mode enabled
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>

" Define menu for encoding
noremenu Encoding.iso-latin1 :e ++enc=iso-8859-1<CR>
noremenu Encoding.UTF-8 :e ++enc=utf-8<CR>
noremenu Encoding.cp1251 :e ++enc=cp1251<CR>
nnoremap <F5> :emenu Encoding.<C-Z>

nnoremap <F6> :browse oldfiles<CR>

" Map <F3> and <S-F3> to jump between locations in a quickfix list, or
" differences if in window in diff mode
nnoremap <expr> <silent> <F3>   (&diff ? "]c" : ":cnext\<CR>")
nnoremap <expr> <silent> <S-F3> (&diff ? "[c" : ":cprev\<CR>")

" http://unix.stackexchange.com/questions/43526/is-it-possible-to-create-and-use-menus-in-terminal-based-vim
if !empty(glob("$VIMRUNTIME/menu.vim"))
  source $VIMRUNTIME/menu.vim
endif
nnoremap \ :emenu <C-Z>

" Speed up scrolling of the viewport slightly
nnoremap <C-E> 2<C-E>
nnoremap <C-Y> 2<C-Y>

" Use arrows to scroll
nnoremap <C-UP> <C-Y>
nnoremap <C-DOWN> <C-E>

" Cursor movement by visual line
inoremap <UP> <C-O>gk
inoremap <DOWN> <C-O>gj
nnoremap <UP> gk
nnoremap <DOWN> gj
vnoremap <UP> gk
vnoremap <DOWN> gj

" Map Y to act like D and C, i.e. to yank until EOL (which is more logical, but not Vi-compatible),
" rather than act as yy
map Y y$

" Copy line N and paste it before the current line.
" Ex.: 15_
nnoremap _ ggyy``P

" Delete to EOL in insert mode. Does it work?
inoremap <C-DEL> <C-\><C-o>D

" http://blog.learnr.org/post/59098925/configuring-vim-some-mo...
map H ^
map L $

" Repeatedly shift indenting while maintaining a visual selection
vnoremap < <gv
vnoremap > >gv

" http://vimrcfu.com/snippet/77
" Move visual block up and down and re-indent (if you don't like that, remove the 'gv=' in the middle)
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" http://usevim.com/2015/02/20/vim-tricks/
nnoremap <C-J> :m+<CR>==
nnoremap <C-K> :m-2<CR>==
vnoremap <C-J> :m'>+<CR>gv=gv
vnoremap <C-K> :m-2<CR>gv=gv

" Start an external command with a single bang
nnoremap ! :! 

" http://vim.wikia.com/wiki/Easier_buffer_switching

" List buffers and pick by number
nnoremap <Leader>0 :ls!<CR>:buffer #

" List buffers and pick by name fragment
nnoremap <F10> :ls!<CR>:buffer<Space>

" Next buffer
nnoremap <silent> <F9> :bn<CR>
imap <silent> <F9> <C-\><C-o><F9>
" Previous buffer
nnoremap <silent> <S-F9> :bp<CR>
imap <silent> <S-F9> <C-\><C-o><S-F9>

" Next window
nnoremap <F12> <C-W>w
inoremap <F12> <C-W>w
" Previous window
nnoremap <S-F12> <C-W>W
inoremap <S-F12> <C-W>W

" List buffers
nnoremap <Leader>l :ls!<CR>

nnoremap <Leader>1 :1b<CR>
nnoremap <Leader>2 :2b<CR>
nnoremap <Leader>3 :3b<CR>
nnoremap <Leader>4 :4b<CR>
nnoremap <Leader>5 :5b<CR>
nnoremap <Leader>6 :6b<CR>
nnoremap <Leader>7 :7b<CR>
nnoremap <Leader>8 :8b<CR>
nnoremap <Leader>9 :9b<CR>

" edit vimrc and load vimrc bindings
nnoremap <leader>vv :vsp $MYVIMRC<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

" Reload from disk, discarding changes
nnoremap <Leader>R :edit!<CR>

" Based on http://vim.wikia.com/wiki/Easy_edit_of_files_in_the_same_directory
" Open menu to select files in the same dir
nnoremap <Leader>ee :e <C-R>=expand('%:p:h') . '/'<CR><C-D>

" Command line abbreviation: %% expands to file's directory.
" Example: type :e %%/
cabbr <expr> %% expand('%:p:h')

" cd to file's directory
" See http://vim.wikia.com/wiki/VimTip64
nnoremap <Leader>cd :cd <C-R>=expand('%:p:h')<CR><CR>

" Open menu to select file (from Current dir) to edit
nnoremap <Leader>e :e <C-D>

" Netrw directory listing at current dir
nnoremap <Leader>E :E<CR>

" Netrw directory listing at file's directory
nnoremap <Leader>EE :E <C-R>=expand('%:p:h') . '/'<CR><CR>

nnoremap <Leader>f :find <C-R>='**'<CR>

nnoremap <Leader>ff :find <C-R>=expand('%:p:h') . '/**'<CR>

nnoremap <Leader>n :10new<CR>

" Close current window but keep buffer (hide it)
nnoremap <F4> <C-w>c

" Close buffer and its window if no changes
nnoremap <Leader>w :bd<CR>
" Close buffer and its window, discarding changes
nnoremap <Leader>W :bd!<CR>

" Quit if no changes. Prompt if there are unsaved buffers
nnoremap <Leader>q :confirm :qa<CR>
" Discard changes and quit with an error
nnoremap <Leader>Q :cq<CR>

" Save current buffer if modified
nnoremap <Leader>s :update<CR>

" Save all buffers
nnoremap <Leader>S :wa<CR>

" http://unix.stackexchange.com/questions/93144/exit-vim-more-quickly
"Fast quit and save from normal and insert mode. ZZ is good too.
nnoremap <C-X> :xa<CR>
" Doesn't seem to work
imap <C-X> <C-\><C-o><C-X>

" sudo to write
cmap w!! w !sudo tee % >/dev/null

" toggle gundo
" http://sjl.bitbucket.org/gundo.vim/
" nnoremap <leader>u :GundoToggle<CR>

" CtrlP settings
" https://github.com/kien/ctrlp.vim.git
let g:ctrlp_match_window = 'bottom,order:ttb'
let g:ctrlp_switch_buffer = 0
let g:ctrlp_working_path_mode = 0
let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'

" http://vim.wikia.com/wiki/Display_line_numbers
highlight LineNr term=NONE cterm=Italic ctermfg=Black ctermbg=Green gui=NONE guifg=DarkBlue guibg=NONE

" http://vim.wikia.com/wiki/Show_fileencoding_and_bomb_in_the_status_line
" http://stackoverflow.com/questions/5547943/display-number-of-current-buffer
" Status Line {
  hi StatusLine term=bold,reverse cterm=bold ctermfg=White ctermbg=Black
  hi StatusLineNC term=reverse cterm=italic ctermfg=Black ctermbg=DarkGrey
  set laststatus=2                             " always show statusbar
  set statusline=
  set statusline+=%-3n\                        " buffer number
  set statusline+=%t\                          " file name (no path). Type <CTRL>-G to see full path
  set statusline+=%h%m%r%w                     " status flags
  set statusline+=%{\"[\".(&fenc==\"\"?&enc:&fenc).((exists(\"+bomb\")\ &&\ &bomb)?\",B\":\"\").\"]\ \"}%k
  set statusline+=\[%{strlen(&ft)?&ft:'none'}] " file type
  set statusline+=%=                           " right align remainder
  set statusline+=0x%-8B                       " character value
  set statusline+=%-14(%l/%L,%c%V%)            " line, character
  set statusline+=%<%P                         " file position
"}
