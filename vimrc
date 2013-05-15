set nocompatible
set smartindent
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set paste
set number 

colorscheme desert

" pathogen
execute pathogen#infect()

" Python style indent
autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4

" Removes trailing whitespace on quit.  Saves me from pep8 bitching.
autocmd BufWritePre *.py :%s/\s\+$//e

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

filetype indent on
filetype plugin on
syntax on

" highlights lines over 80 columns wide
highlight OverLength ctermbg=darkblue ctermfg=white guibg=#FFD9D9
match OverLength /\%81v.\+/
