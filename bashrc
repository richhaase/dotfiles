#!/bin/bash
export PS1="    \j job(s) [\t] \n`if [[ $USER == \"root\" ]]; then echo "\# #"; else echo "(\u@\h) \W>$ "; fi`"
export JAVA_HOME=$(/usr/libexec/java_home)
export JAVA_OPTS=-Xmx768m
export HADOOP_HOME=/usr/local/hadoop
export WUKONG_BIN=/Users/rdh/.rvm/gems/ruby-1.9.3-p194@global/gems/wukong-2.0.2/bin/
export PATH=~/.bin:~/.rvm/bin:$HADOOP_HOME/bin:/bin:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/opt/local/bin:/opt/local/sbin:$WUKONG_BIN
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

set -o vi

alias b='echo -n "sourcing .bashrc... " && source ~/.bashrc && echo "done"'
alias r='cd ~/Dropbox/code/ruby'
alias j='jobs'
alias spec='rspec'

function size() {
  find . | wc -l | awk '{print $1" files"}'
  du -sh | awk '{print "Total size: "$1}'
}

function mkproj() {
  mkdir $1
  mkdir $1/{bin,lib,spec,features}
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
