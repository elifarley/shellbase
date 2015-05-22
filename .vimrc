" http://vim.wikia.com/wiki/Toggle_auto-indenting_for_code_paste
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>
set showmode

" Tips: http://dougblack.io/words/a-good-vimrc.html

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
set wildmenu            " Visual autocomplete for command menu
set showmatch           " Highlight matching [{()}]
" Highlight last inserted text
nnoremap gV `[v`]

set hlsearch            " Highlight matches
set incsearch           " Search as characters are entered

let mapleader=" "       " Leader is space

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
