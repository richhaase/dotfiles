set smartindent
set autoindent
set tabstop=4
set shiftwidth=4
set expandtab
set number
set paste

autocmd FileType ruby setlocal expandtab shiftwidth=2 softtabstop=2
autocmd FileType scala setlocal expandtab shiftwidth=2 softtabstop=2

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

filetype indent on
filetype plugin on
syntax on
