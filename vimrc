" pathogen
filetype off
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

filetype on
set nocompatible
set smartindent
set autoindent
set tabstop=4
set shiftwidth=4
set expandtab
set number 
set background=dark
set foldmethod=indent
set foldlevel=99
set hidden
set laststatus=2
set t_Co=256

" Python style indent
autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

filetype indent on 
filetype plugin on 
syntax enable
syntax on

" buffer shortcuts
nnoremap th :bp<CR>
nnoremap tl :bn<CR>
nnoremap te :e<Space>
nnoremap td :bd<CR>

" NERDTree
nmap <silent> <C-T> :NERDTreeToggle<CR>

" CtrlP
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'

" airline config
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

