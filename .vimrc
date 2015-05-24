" Tips: http://dougblack.io/words/a-good-vimrc.html

" http://vim.wikia.com/wiki/Toggle_auto-indenting_for_code_paste
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>
set showmode

set t_Co=256 " enable colorscheme

" https://raw.githubusercontent.com/sjl/badwolf/master/colors/badwolf.vim
" save it to ~/.vim/colors/badwolf.vim
let g:badwolf_darkgutter = 1
let g:badwolf_css_props_highlight = 1
"colorscheme badwolf

" https://raw.githubusercontent.com/jnurmine/Zenburn/master/colors/zenburn.vim
let g:zenburn_alternate_Visual = 1 " More contrast in Visual Selection
let g:zenburn_unified_CursorColumn = 1
"let g:zenburn_high_Contrast = 1
colorscheme zenburn

syntax enable

set tabstop=2       " Number of visual spaces per TAB
set softtabstop=2   " Number of spaces in tab when editing
set expandtab       " Tabs are spaces

"set number             " Show line numbers
set showcmd             " Show command in bottom bar
set cursorline          " Highlight current line
set cursorcolumn        " Highlight current column
set wildmenu wildmode=full " Visual autocomplete for command menu
set showmatch           " Highlight matching [{()}]
" Highlight last inserted text
nnoremap gV `[v`]

set hlsearch            " Highlight matches
set incsearch           " Search as characters are entered
set ignorecase smartcase " lowercase-only search terms will match uppercase text too

let mapleader=" "       " Leader is space

" http://vim.wikia.com/wiki/Easier_buffer_switching

set hidden " so that buffers with unsaved changes can be hidden

" list buffers and let you choose which to open
nnoremap <F6> :ls!<CR>:buffer<Space>

" Press F10 to open the buffer menu
set wildcharm=<C-Z>
nnoremap <F10> :b <C-Z>
" Also useful: {count}CTRL-^ to edit buffer {count}
" and CTRL-^ to edit last edited file

" Next buffer
nnoremap <silent> <F12> :bn<CR>
" Previous buffer
nnoremap <silent> <S-F12> :bp<CR>

" List buffers
nnoremap <Leader>l :ls!<CR>

nnoremap <Leader>g :e#<CR>

nnoremap <Leader>n :enew<CR>

nnoremap <Leader>1 :1b<CR>
nnoremap <Leader>2 :2b<CR>
nnoremap <Leader>3 :3b<CR>
nnoremap <Leader>4 :4b<CR>
nnoremap <Leader>5 :5b<CR>
nnoremap <Leader>6 :6b<CR>
nnoremap <Leader>7 :7b<CR>
nnoremap <Leader>8 :8b<CR>
nnoremap <Leader>9 :9b<CR>
nnoremap <Leader>0 :b <C-Z>

" edit vimrc and load vimrc bindings
nnoremap <leader>ev :vsp ~/.vimrc<CR>
nnoremap <leader>sv :source ~/.vimrc<CR>

" toggle gundo
" http://sjl.bitbucket.org/gundo.vim/
" nnoremap <leader>u :GundoToggle<CR>

" CtrlP settings
" https://github.com/kien/ctrlp.vim.git
" let g:ctrlp_match_window = 'bottom,order:ttb'
" let g:ctrlp_switch_buffer = 0
" let g:ctrlp_working_path_mode = 0
" let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'

" http://vim.wikia.com/wiki/Show_fileencoding_and_bomb_in_the_status_line
if has("statusline")
 set statusline=%<%f\ %h%m%r%=%{\"[\".(&fenc==\"\"?&enc:&fenc).((exists(\"+bomb\")\ &&\ &bomb)?\",B\":\"\").\"]\ \"}%k\ %-14.(%l,%c%V%)\ %P
endif
