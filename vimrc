call plug#begin()

" Git
Plug 'tpope/vim-fugitive'

" Airline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" NERDTree
Plug 'preservim/nerdtree', { 'on': 'NERDTreeToggle' }

" ctrl+p
Plug 'kien/ctrlp.vim'

" Python
Plug 'vim-syntastic/syntastic'
Plug 'nvie/vim-flake8'


call plug#end()

syntax on 

" Change how vim represents characters on the screen
set encoding=utf-8

" Set the encoding of files written
set fileencoding=utf-8

" default tab settings
set expandtab tabstop=2 shiftwidth=2 softtabstop=2 textwidth=79

autocmd Filetype python setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4 textwidth=79 autoindent fileformat=unix
autocmd BufWritePre *.py :%s/\s\+$//e

filetype plugin indent on

" Allow backspace to delete indentation and inserted text
" i.e. how it works in most programs
" indent  allow backspacing over autoindent
" eol     allow backspacing over line breaks (join lines)
" start   allow backspacing over the start of insert; CTRL-W and CTRL-U
"        stop once at the start of insert.
set backspace=indent,eol,start

" Hardcore mode, disable arrow keys.
noremap <Up> <NOP>
noremap <Down> <NOP>
noremap <Left> <NOP>
noremap <Right> <NOP>

"split navigations
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
nnoremap re :resize 10<CR>

" tab shortcuts
nnoremap tr :split term://zsh<CR>
nnoremap rz :resize 10<CR>
nnoremap th :tabp<CR>
nnoremap tl :tabn<CR>
nnoremap te :tabedit<Space>
nnoremap td :tabc<CR>

"" NERDTree config
nmap <silent> <C-T> :NERDTreeToggle<CR>

"" airline config
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#ctrlp#color_template = 'insert'
let g:airline#extensions#ctrlp#color_template = 'normal'
let g:airline#extensions#ctrlp#color_template = 'visual'
let g:airline#extensions#ctrlp#color_template = 'replace'
let g:airline#extensions#virtualenv#enabled = 1
let g:airline#extensions#whitespace#enabled = 1
let g:airline#extensions#whitespace#symbol = '!'
let g:airline#extensions#whitespace#checks = [ 'indent', 'trailing' ]
let g:airline#extensions#whitespace#show_message = 1
let g:airline#extensions#whitespace#trailing_format = 'trailing[%s]'
let g:airline#extensions#whitespace#mixed_indent_format = 'mixed-indent[%s]'
let g:airline#extensions#tabline#enabled = 1
let g:airline_left_sep = '▶'
let g:airline_right_sep = '◀'
let g:airline_detect_modified=1
let g:airline_detect_paste=1
let g:airline_powerline_fonts=0
