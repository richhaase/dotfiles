set smartindent
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set number
set paste

autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

filetype indent on
filetype plugin on
syntax on
