set smartindent
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set number

" Saw this in a peepcode screencast.  great to be able to fat finger :W/:Wq/:Q
command! W :w
command! Wq :wq
command! Q :q


filetype indent on	    	" Enable filetype detection
compiler ruby		          " Ruby compiler support
syntax on
