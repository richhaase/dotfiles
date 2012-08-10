set smartindent
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set number

set lines=50 
set columns=160

autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q

" Pig syntax highlighting ftw!
augroup filetypedetect 
    au BufNewFile,BufRead *.pig set filetype=pig syntax=pig 
  augroup END 

filetype indent on	    	" Enable filetype detection
compiler ruby		          " Ruby compiler support
syntax on
