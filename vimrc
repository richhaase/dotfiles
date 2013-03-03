execute pathogen#infect()

set nocompatible
set smartindent
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set paste
set number 

colorscheme desert

autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4

" Removes trailing whitespace on quit.  Saves me form pep8 bitching.
autocmd BufWritePre *.py :%s/\s\+$//e

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

filetype indent on
filetype plugin on
syntax on

let g:haddock_browser = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

