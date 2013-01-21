#!/bin/bash

export ANDROID=/Users/rdh/src/adt-bundle-mac-x86_64/sdk
export ANDROID_TOOLS=${ANDROID}/tools
export PS1="`if [[ $USER == \"root\" ]]; then echo "\# #"; else echo "\h:\u \W>$ "; fi`"
export JAVA_OPTS=-Xmx768m
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad
export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:/usr/local/mysql/lib/

if [[ `uname -s` == "Darwin" ]]; then
  export JAVA_HOME=$(/usr/libexec/java_home)
  export PATH=~/.bin:/opt/local/bin:/opt/local/sbin:$ANDROID_TOOLS:/bin:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/local/mysql/bin
elif [[ `uname -s` == "Linux" ]]; then
  export PATH=~/.bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
fi

alias b='echo -n "sourcing .bashrc... " && source ~/.bashrc && echo "done"'
alias j='jobs'
alias pyunset='unset PYTHONPATH'
alias pypath='echo $PYTHONPATH'

function pyset() {
    if [ "x$PYTHONPATH" != "x" ]
    then 
        PYTHONPATH=$PYTHONPATH:`pwd`
    else
        PYTHONPATH=`pwd`
    fi
    export PYTHONPATH
}

function si() {
  find . | wc -l | awk '{print $1" files"}'
  du -sh | awk '{print "Total size: "$1}'
}

function dot() {

  if [ -z $1 ]; then
    echo "usage: dot pull|push"
    return 191
  fi

	SAVE=`pwd`
	cd ~/dotfiles

  case $1 in 
    "push" ) 
      echo -n "comment: "
      read $comment
      git add ~/dotfiles/*
      git commit -am \"$comment\"
      git push
      ;;
    "pull" )
	    git pull
	    ./setup.sh
	    source ~/.bash_profile
      ;;
  esac

	cd $SAVE
}

if [ -f ~/.local_bashrc ]; then
  . ~/.local_bashrc
fi
