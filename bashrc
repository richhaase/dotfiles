#!/bin/bash

export PS1="`if [[ $USER == \"root\" ]]; then echo "\# #"; else echo "\h:\u \W>$ "; fi`"
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

if [[ `uname -s` == "Darwin" ]]; then
  export PATH=~/.bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin
elif [[ `uname -s` == "Linux" ]]; then
  export PATH=~/.bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
fi

alias last='cd $OLDPWD'
alias j='jobs'
alias pg='pg_ctl -D /usr/local/pgsql/data -l /usr/local/pgsql/data/logfile $1'

function si() {
  find . | wc -l | awk '{print $1" files"}'
  du -sh | awk '{print "Total size: "$1}'
}

if [ -f ~/.local_bashrc ]; then
  . ~/.local_bashrc
fi

# virtualenv wrapper
export WORKON_HOME=~/src/python
source /usr/local/bin/virtualenvwrapper.sh

set -o emacs
export EDITOR=/usr/local/bin/vim

export JAVA_HOME="$(/usr/libexec/java_home)"
