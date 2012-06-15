set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set number

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq
command! W :w
command! Wq :wq

filetype on	    	" Enable filetype detection
compiler ruby		" Ruby compiler support
syntax on
