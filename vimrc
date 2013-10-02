" pathogen
filetype off
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

filetype on
set nocompatible
set smartindent
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set paste
set number 
set background=dark
set foldmethod=indent
set foldlevel=99

" Python style indent
autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

filetype indent on 
filetype plugin on 
syntax on

map <leader>g :GundoToggle<CR>
nmap <silent> <C-T> :NERDTreeToggle<CR>

" miniBufExpl
let g:miniBufExplMapWindowNavVim = 1

" syntastic 
let g:syntastic_python_flake8_args = "--ignore=E501"
let g:syntastic_python_flake8_args = "--max-line-length=160"
