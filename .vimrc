" http://vim.wikia.com/wiki/Toggle_auto-indenting_for_code_paste
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>
set showmode

" Tips: http://dougblack.io/words/a-good-vimrc.html

" https://raw.githubusercontent.com/sjl/badwolf/master/colors/badwolf.vim
" save it to ~/.vim/colors/badwolf.vim
"colorscheme badwolf

" https://raw.githubusercontent.com/jnurmine/Zenburn/master/colors/zenburn.vim
colorscheme zenburn


syntax enable

set tabstop=2       " number of visual spaces per TAB
set softtabstop=2   " number of spaces in tab when editing
set expandtab       " tabs are spaces

"set number            " show line numbers
set showcmd             " show command in bottom bar
set cursorline          " highlight current line
set wildmenu            " visual autocomplete for command menu
set showmatch           " highlight matching [{()}]

set incsearch           " search as characters are entered
set hlsearch            " highlight matches

" highlight last inserted text
nnoremap gV `[v`]

let mapleader=" "       " leader is space

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
