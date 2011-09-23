export PS1='\t \h:\W>$ '
export CLICOLOR="yes"
#export JAVA_HOME=$(/usr/libexec/java_home)

alias ls="ls -G"
alias jslint="/Users/rdh/node_modules/jslint/bin/jslint.js"
alias vi="vim"

function s2d () {
  delete=""
  if [[ $1 == "del" || $1 == "rm" ]]; then
      delete="--delete"
  fi
  rsync -avz $delete /Users/rdh/code/ /Users/rdh/Dropbox/code
  rsync -avz $delete /Users/rdh/Documents/Regis/ /Users/rdh/Dropbox/Regis
}

function d2s () {
  delete=""
  if [[ $1 == "del" || $1 == "rm" ]]; then
      delete="--delete"
  fi
  rsync -avz $delete /Users/rdh/Dropbox/code/ /Users/rdh/code
  rsync -avz $delete /Users/rdh/Dropbox/Regis/ /Users/rdh/Documents/Regis
}

function lib2cs434 () {
  rsync -avz /Users/rdh/NetBeansProjects/Library/ \
      /Users/rdh/Documents/Regis/CS434/Library
}
