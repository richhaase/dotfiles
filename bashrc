#!/bin/bash

export HADOOP_HOME=/usr/local/hadoop
export PS1="`if [[ $USER == \"root\" ]]; then echo "\# #"; else echo "\h:\u \W>$ "; fi`"
export JAVA_OPTS=-Xmx768m
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

if [[ `uname -s` == "Darwin" ]]; then
  export JAVA_HOME=$(/usr/libexec/java_home)
  export SCALA_BIN=/usr/local/scala/bin
  export PATH=~/.bin:/opt/local/bin:/opt/local/sbin::$HADOOP_HOME/bin:/bin:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/local/mysql/bin:$SCALA_BIN
elif [[ `uname -s` == "Linux" ]]; then
  export PATH=~/.bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
fi

alias b='echo -n "sourcing .bashrc... " && source ~/.bashrc && echo "done"'
alias j='jobs'
alias msync='rsync -avz ~/Music/ /Volumes/Data/Music/'

function si() {
  find . | wc -l | awk '{print $1" files"}'
  du -sh | awk '{print "Total size: "$1}'
}

function mkproj() {
  mkdir $1
  mkdir $1/{bin,lib,spec}
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
