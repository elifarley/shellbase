" Tips:
" http://learnvimscriptthehardway.stevelosh.com/
" https://www.cs.cornell.edu/courses/cs312/2006fa/software/quick-vim.pdf
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
" <F1> - Default (help)
" <F2> - pastetoggle
" <C-F2> - Toggle line numbers and special chars for each window
" <F3> - gd (go to definition, similar to Eclipse)
" <F4> - :bd (close buffer and its window if no changes)
" <C-F4> - Only current window ( not working - try <C-w>o )
" <F5> - Preview window
" <F6,S-> - Next/prev buffer
" <F7,S-> - Jump between locations in a quickfix or location list
" <C-F7> - Show location or quickfix list + go to item (llist! / clist!) + (ll / cc)
" <F8> - Go to location or quickfix item (ll / cc)
" <F9> - <C-w>p (previous / alternate window)
" <C-F9> - :TagbarToggle
" <C-F10> Menu: Encoding
" <F11> - Browse oldfiles
" <F12> Alternate buffers (current and last)
" <S-F12> List buffers and pick by number or name fragment
" <C-F12> CtrlP
" --

" <Esc> alternatives: jk and <CTRL>-[ and <CTRL>-C and <ALT>-<ENTER>
" and <ALT>-<SPACE> or use <ALT>-<normal mode key>
" See http://vim.wikia.com/wiki/Avoid_the_escape_key

" Use {count}<CTRL>-^ to edit buffer {count}
" and <CTRL>-^ to edit last edited file
" (or <SPACE>-0 to choose what buffer to edit)

" <CTRL>-I and <CTRL>-o to navigate visited places, even in closed buffers
" or from the last time you opened vim.
" (Ex.: open vim and type <C-o> to open last file)
" http://vim.wikia.com/wiki/Using_marks:
" Type m followed by lowercase letter to mark pos in current file
"   Use UPPERCASE to set global mark
"   ' or ` to jump to a mark
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

filetype off                  " required
" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
" Add CtrlP plugin
Plugin 'ctrlpvim/ctrlp.vim'
call vundle#end()            " required
filetype plugin indent on    " required

" See http://vim.wikia.com/wiki/Mapping_fast_keycodes_in_terminal_Vim
" More at http://mg.pov.lt/vim/vimrc
" http://unix.stackexchange.com/questions/76566/where-do-i-find-a-list-of-terminal-key-codes-to-remap-shortcuts-in-bash
" Try cat
" See https://github.com/mgedmin/dotvim/blob/master/plugin/keyboard-workarounds.vim
map ^[[1;5P <C-F1>
map ^[[1;5Q <C-F2>
map ^[[1;5R <C-F3>
map ^[[1;5S <C-F4>
map ^[[15;5~ <C-F5>
map ^[[17;5~ <C-F6>
map ^[[18;5~ <C-F7>
map ^[[19;5~ <C-F8>
map ^[[20;5~ <C-F9>
map ^[[21;5~ <C-F10>
map ^[[23;5~ <C-F11>
map ^[[24;5~ <C-F12>

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

" Enable mouse. To copy to OS clipboard, keep <SHIFT> pressed
set mouse=a
"set ttymouse=xterm2

" Kitty support
" https://sw.kovidgoyal.net/kitty/faq/#using-a-color-theme-with-a-background-color-does-not-work-well-in-vim

set ttymouse=sgr
set balloonevalterm
" Styled and colored underline support
let &t_AU = "\e[58:5:%dm"
let &t_8u = "\e[58:2:%lu:%lu:%lum"
let &t_Us = "\e[4:2m"
let &t_Cs = "\e[4:3m"
let &t_ds = "\e[4:4m"
let &t_Ds = "\e[4:5m"
let &t_Ce = "\e[4:0m"
" Strikethrough
let &t_Ts = "\e[9m"
let &t_Te = "\e[29m"
" Truecolor support
let &t_8f = "\e[38:2:%lu:%lu:%lum"
let &t_8b = "\e[48:2:%lu:%lu:%lum"
let &t_RF = "\e]10;?\e\\"
let &t_RB = "\e]11;?\e\\"
" Bracketed paste
let &t_BE = "\e[?2004h"
let &t_BD = "\e[?2004l"
let &t_PS = "\e[200~"
let &t_PE = "\e[201~"
" Cursor control
let &t_RC = "\e[?12$p"
let &t_SH = "\e[%d q"
let &t_RS = "\eP$q q\e\\"
let &t_SI = "\e[5 q"
let &t_SR = "\e[3 q"
let &t_EI = "\e[1 q"
let &t_VS = "\e[?12l"
" Focus tracking
let &t_fe = "\e[?1004h"
let &t_fd = "\e[?1004l"
execute "set <FocusGained>=\<Esc>[I"
execute "set <FocusLost>=\<Esc>[O"
" Window title
let &t_ST = "\e[22;2t"
let &t_RT = "\e[23;2t"

" vim hardcodes background color erase even if the terminfo file does
" not contain bce. This causes incorrect background rendering when
" using a color theme with a background color in terminals such as
" kitty that do not support background color erase.
let &t_ut=''

" /Kitty ######################


set t_Co=256 " enable colorscheme
" Please add 'term screen-256color' to ~/.screenrc
set background=dark

" https://raw.githubusercontent.com/sjl/badwolf/master/colors/badwolf.vim
" save it to ~/.vim/colors/badwolf.vim
if filereadable(expand("~/.vim/colors/badwolf.vim"))
  let g:badwolf_darkgutter = 1
  let g:badwolf_css_props_highlight = 1
  "colorscheme badwolf
endif

" https://raw.githubusercontent.com/jnurmine/Zenburn/master/colors/zenburn.vim
if filereadable(expand("~/.vim/colors/zenburn.vim"))
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
set history=10000 " Store lots of :cmdline history
set undolevels=10000 " Use many muchos levels of undo
set undoreload=50000

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

set completeopt=menuone,noinsert,noselect

set omnifunc=syntaxcomplete#Complete

" See http://vim.wikia.com/wiki/VimTip1386
:inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
inoremap <expr> <C-n> pumvisible() ? '<C-n>' :
  \ '<C-n><C-r>=pumvisible() ? "\<lt>Down>" : ""<CR>'
inoremap <expr> <M-,> pumvisible() ? '<C-n>' :
  \ '<C-x><C-o><C-n><C-p><C-r>=pumvisible() ? "\<lt>Down>" : ""<CR>'

" Omni completion mapping
inoremap <C-Space> <C-x><C-o>
" Some terminals send <C-@> for Ctrl+Space
inoremap <C-@> <C-x><C-o>

set expandtab       " Tabs are spaces
set smarttab        " Insert tabs on the start of a line according to shiftwidth, not tabstop
set tabstop=2       " Number of visual spaces per TAB
set shiftwidth=2   " Used when indenting with >> and <<
set softtabstop=2   " Number of spaces in tab when editing
set shiftround      " Use multiple of shiftwidth when indenting with '<' and '>'
set copyindent      " copy the previous indentation on autoindenting

" Quickly time out on keycodes
set ttimeout ttimeoutlen=200

set backspace=indent,eol,start " allow backspacing over everything in insert mode

set hidden " so that buffers with unsaved changes can be hidden
set nobackup
set nowritebackup

set title              " change the terminal's title
set showcmd             " Show incomplete cmds down the bottom
" Set the command window height to 2 lines, to avoid many cases of having to
" press <Enter> to continue"
set cmdheight=2
set showmode            " Show current mode down the bottom
set cursorline          " Highlight current line
set cursorcolumn        " Highlight current column
set signcolumn=yes

augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
augroup END
set number relativenumber   " Show hybrid line numbers
" http://vim.wikia.com/wiki/Display_line_numbers
" Set the color for normal line numbers
highlight LineNr term=NONE cterm=Italic ctermfg=Black ctermbg=DarkGrey gui=NONE guifg=DarkBlue guibg=NONE

" Set the color for the current line number
" highlight CursorLineNr ctermfg=lightgreen ctermbg=darkgreen

" Custom vertical highlight
highlight CursorColumn ctermbg=234 guibg=#1c1c1c

set formatoptions-=o "dont continue comments when pushing o/O

" Vertical/horizontal scroll off settings
set scrolloff=3
set sidescrolloff=7
set sidescroll=1

set splitright
set splitbelow
" Use <C-w> s to split; <C-v> for a vertical split

set wildmenu                " Enable ctrl-n and ctrl-p to scroll thru matches
"set wildmode=list:longest   " make cmdline tab completion similar to bash
set wildmode=list:longest,full " better
set wildignore=*.o,*.obj,*~,*.swp,*.bak,*.pyc,*.class " Stuff to ignore when tab completing

set wildcharm=<C-Z>

let mapleader=" "       " Leader is space

" http://unix.stackexchange.com/a/186558/46796
" nno : ;
" nno ; :
" vno : ;
" vno ; :

" Good for Brazillian ABNT2 keyboards
nno ç :

inoremap jk <esc>

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

" Display all lines that contain the keyword under the cursor
nnoremap & [I

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
nnoremap <C-F2> :setlocal number!<BAR>setlocal list!<CR>
nmap <C-N><C-N> <C-F2>

" http://vim.wikia.com/wiki/Toggle_auto-indenting_for_code_paste
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>

" Preview window
nnoremap <F5> <C-w>P
inoremap <F5> <C-\><C-o><C-w>P

" Map <F7> and <S-F7> to jump between locations in a quickfix list, or
" differences if in window in diff mode
nnoremap <expr> <silent> <F7>   (&diff ? "]c" : ":cnext\<CR>")
nnoremap <expr> <silent> <S-F7> (&diff ? "[c" : ":cprev\<CR>")

nnoremap <expr> <C-F7> (&diff ? ":llist!\<CR>:ll<Space>" : ":clist!\<CR>:cc<Space>")
nnoremap <expr> <F8> (&diff ? ":ll<Space>" : ":cc<Space>")

nnoremap <C-F9> :TagbarToggle<CR>
imap <C-F9> <C-\><C-o><C-F9>

nnoremap <F9> <C-w>p
inoremap <F9> <C-\><C-o><C-w>p

" Define menu for encoding
noremenu Encoding.iso-latin1 :e ++enc=iso-8859-1<CR>
noremenu Encoding.UTF-8 :e ++enc=utf-8<CR>
noremenu Encoding.cp1251 :e ++enc=cp1251<CR>
nnoremap <F10> :emenu Encoding.<C-Z>

nnoremap <F11> :browse oldfiles<CR>
inoremap <F11> <C-\><C-o>:browse oldfiles<CR>

" Switch buffers (go to last used)
nnoremap <F12> <C-^>
imap <F12> <C-\><C-o><F12>

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

" See http://vim.wikia.com/wiki/Replace_a_word_with_yanked_text
" nnoremap S diw"0P
nnoremap S "_diwP
" vnoremap S "_d"0P
vnoremap S "_dP

" Copy line N and paste it before the current line.
" Ex.: 15_
nnoremap _ ggyy``P

" Delete to EOL in insert mode. Does it work?
inoremap <C-DEL> <C-\><C-o>D

" Repeatedly shift indenting while maintaining a visual selection
vnoremap < <gv
vnoremap > >gv

" http://vimrcfu.com/snippet/77
" Move visual block up and down and re-indent (if you don't like that, remove the 'gv=' in the middle)
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" http://usevim.com/2015/02/20/vim-tricks/
" Move current line or visual selection, adjusting indentation
nnoremap <C-J> :m+<CR>==
nnoremap <C-K> :m-2<CR>==
vnoremap <C-J> :m'>+<CR>gv=gv
vnoremap <C-K> :m-2<CR>gv=gv

" Start an external command with a single bang
nnoremap ! :!

" edit vimrc and load vimrc bindings
nnoremap <leader>vv :vsp $MYVIMRC<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>

" Go to definition, NOT the same as <C-]>
nnoremap <F3> gd
imap <F3> <C-\><C-o><F3>

" Buffer Management

" http://vim.wikia.com/wiki/Easier_buffer_switching

nnoremap <Leader>n :10new<CR>
nnoremap <Leader>N :enew<CR>

" Next buffer
nnoremap <silent> <F6> :bn<CR>
" ALT right-arrow
nmap <silent> <Esc>[1;3C <F6>
imap <silent> <F6> <C-\><C-o><F6>
imap <silent> <Esc>[1;3C <C-\><C-o><F6>

" Previous buffer
nnoremap <silent> <S-F6> :bp<CR>
" ALT left-arrow
nmap <silent> <Esc>[1;3D <S-F6>
imap <silent> <S-F6> <C-\><C-o><S-F6>
imap <silent> <Esc>[1;3D <C-\><C-o><S-F6>

" Same as <C-w>o
nnoremap <C-F4> :only<CR>
inoremap <C-F4> <C-\><C-o>:only<CR>

" List buffers and pick by number or name fragment
nnoremap <S-F12> :ls!<CR>:buffer<Space>
nnoremap <Leader>l :ls!<CR>:buffer<Space>
" List buffers and pick by number or name fragment
nnoremap <Leader>0 :ls!<CR>:buffer<Space>

nnoremap <Leader>1 :1b<CR>
nnoremap <Leader>2 :2b<CR>
nnoremap <Leader>3 :3b<CR>
nnoremap <Leader>4 :4b<CR>
nnoremap <Leader>5 :5b<CR>
nnoremap <Leader>6 :6b<CR>
nnoremap <Leader>7 :7b<CR>
nnoremap <Leader>8 :8b<CR>
nnoremap <Leader>9 :9b<CR>

" Paste
xnoremap <leader>p "_dP

" Reload from disk, discarding changes
nnoremap <Leader>R :edit!<CR>

" Command line abbreviation: %% expands to file's directory.
" Example: type :e %%/
cabbr <expr> %% expand('%:p:h')

" cd to file's directory
" See http://vim.wikia.com/wiki/VimTip64
nnoremap <Leader>cd :cd <C-R>=expand('%:p:h')<CR><CR>

" Tree style for netrw
let g:netrw_liststyle=3

" Open menu to select file (from Current dir) to edit
nnoremap <Leader>e :e <C-D>

" Based on http://vim.wikia.com/wiki/Easy_edit_of_files_in_the_same_directory
" Open menu to select files in the same dir
nnoremap <Leader>ee :e <C-R>=expand('%:p:h') . '/'<CR><C-D>

" Netrw directory listing at current dir
nnoremap <Leader>E :E<CR>

" Netrw directory listing at file's directory
nnoremap <Leader>EE :E <C-R>=expand('%:p:h') . '/'<CR><CR>

nnoremap <Leader>f :find <C-R>='**'<CR>

nnoremap <Leader>ff :find <C-R>=expand('%:p:h') . '/**'<CR>

" Save current buffer if modified
nnoremap <Leader>s :update<CR>

" http://vim.wikia.com/wiki/Map_Ctrl-S_to_save_current_or_new_files
" Remember to set stty -ixon
nnoremap <C-S> :<C-u>update<CR>
vnoremap <C-S> <ESC>:update<CR>gv
" Doesn't work if paste mode is on
inoremap <C-S> <C-\><C-o>:update<CR>

" Save all buffers
nnoremap <Leader>S :wa<CR>

" sudo to write
cmap w!! w !sudo tee % >/dev/null

" http://unix.stackexchange.com/questions/93144/exit-vim-more-quickly
"Fast save and quit from normal and insert mode. ZZ is good too.
nnoremap <C-X> :xa<CR>
" Doesn't work if paste mode is on
imap <C-X> <C-\><C-o><C-X>

" Close buffer and its window if no changes
nnoremap <F4> :bd<CR>

" Close current window but keep buffer (hide it)
nnoremap <Leader>w <C-w>c
" Close buffer and its window, discarding changes
nnoremap <Leader>W :bd!<CR>

" Quit if no changes. Prompt if there are unsaved buffers
nnoremap <Leader>q :confirm :qa<CR>
" Discard changes and quit with an error
nnoremap <Leader>Q :cq<CR>
" Must enable <C-Q> in terminal using stty start undef
" See http://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
nnoremap <C-Q> :cq<CR>
inoremap <C-Q> <C-\><C-o>:cq<CR>

" toggle gundo
" http://sjl.bitbucket.org/gundo.vim/
" nnoremap <leader>u :GundoToggle<CR>

" CtrlP settings
" https://github.com/ctrlpvim/ctrlp.vim
let g:ctrlp_match_window = 'bottom,order:ttb'
let g:ctrlp_switch_buffer = 0
"let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
if executable('rg')
  let g:ctrlp_user_command = 'rg %s --files --hidden --color=never --glob ""'
endif

" See http://joshldavis.com/2014/04/05/vim-tab-madness-buffers-vs-tabs/
" Setup some default ignores
let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/](\.(git|hg|svn)|\_site)$',
  \ 'file': '\v\.(exe|so|dll|class|png|jpg|jpeg|swp)$',
\}
" Use the nearest .git directory as the cwd
" This makes a lot of sense if you are working on a project that is in version
" control. It also supports works with .svn, .hg, .bzr.
let g:ctrlp_working_path_mode = 'rw'

" Restore default <C-p> behavior
nnoremap <C-p> :<C-p>

" Use a leader instead of the actual named binding
nmap <leader>P :CtrlP<cr>
nnoremap <C-F12> :CtrlP<cr>

" Easy bindings for its various modes
nmap <leader>bb :CtrlPBuffer<cr>
nmap <leader>bm :CtrlPMixed<cr>
nmap <leader>bs :CtrlPMRU<cr>

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


" From https://git.zx2c4.com/password-store/tree/contrib/vim/noplaintext.vim:

" Prevent various Vim features from keeping the contents of pass(1) password
" files (or any other purely temporary files) in plaintext on the system.
"
" Either append this to the end of your .vimrc, or install it as a plugin with
" a plugin manager like Tim Pope's Pathogen.
"
" Author: Tom Ryder <tom@sanctum.geek.nz>
"

" Don't backup files in temp directories or shm
if exists('&backupskip')
    set backupskip+=/tmp/*,$TMPDIR/*,$TMP/*,$TEMP/*,*/shm/*
endif

" Don't keep swap files in temp directories or shm
if has('autocmd')
    augroup swapskip
        autocmd!
        silent! autocmd BufNewFile,BufReadPre
            \ /tmp/*,$TMPDIR/*,$TMP/*,$TEMP/*,*/shm/*
            \ setlocal noswapfile
    augroup END
endif

" Don't keep undo files in temp directories or shm
if has('persistent_undo') && has('autocmd')
    augroup undoskip
        autocmd!
        silent! autocmd BufWritePre
            \ /tmp/*,$TMPDIR/*,$TMP/*,$TEMP/*,*/shm/*
            \ setlocal noundofile
    augroup END
endif

" Don't keep viminfo for files in temp directories or shm
if has('viminfo')
    if has('autocmd')
        augroup viminfoskip
            autocmd!
            silent! autocmd BufNewFile,BufReadPre
                \ /tmp/*,$TMPDIR/*,$TMP/*,$TEMP/*,*/shm/*
                \ setlocal viminfo=
        augroup END
    endif
endif
