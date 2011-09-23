syntax on
set nobackup
set nowritebackup
set noswapfile
set columns=130
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smarttab
set expandtab
set smartindent
filetype indent on
filetype on
filetype plugin on
if has("autocmd")
    autocmd FileType python set complete+=k/Users/rdh/.vim/pydiction/pydiction isk+=.,(
endif" has("autocmd")
let g:pydiction_location='/Users/rdh/.vim/pydiction/complete-dict'
