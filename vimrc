set smartindent
set autoindent
set tabstop=4
set shiftwidth=4
set expandtab
set number

autocmd FileType ruby setlocal expandtab shiftwidth=2 softtabstop=2

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
