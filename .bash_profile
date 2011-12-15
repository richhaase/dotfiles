export PS1='\t \h:\W>$ '
export JAVA_HOME=$(/usr/libexec/java_home)
export JAVA_OPTS=-Xmx768m
export PATH=$PATH:~/bin

function l2d () {
  delete=""
  if [[ $1 == "del" || $1 == "rm" ]]; then
      delete="--delete"
  fi
  rsync -avz $delete /Users/rdh/code/ /Users/rdh/Dropbox/code
  rsync -avz $delete /Users/rdh/Documents/Regis/ /Users/rdh/Dropbox/Regis
}

function d2l () {
  delete=""
  if [[ $1 == "del" || $1 == "rm" ]]; then
      delete="--delete"
  fi
  rsync -avz $delete /Users/rdh/Dropbox/code/ /Users/rdh/code
  rsync -avz $delete /Users/rdh/Dropbox/Regis/ /Users/rdh/Documents/Regis
}

alias emacs='/usr/local/Cellar/emacs/23.3a/bin/emacs'
