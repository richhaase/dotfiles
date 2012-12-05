set smartindent
set autoindent
set tabstop=4
set shiftwidth=4
set expandtab
set paste
set number 

colorscheme zenburn

autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4
autocmd FileType shell setlocal expandtab shiftwidth=2 softtabstop=2

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

filetype indent on
filetype plugin on
syntax on
