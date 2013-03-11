#!/bin/bash

export PS1="`if [[ $USER == \"root\" ]]; then echo "\# #"; else echo "\h:\u \W>$ "; fi`"
export JAVA_OPTS=-Xmx1024m
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad
#export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:/usr/local/mysql/lib/

if [[ `uname -s` == "Darwin" ]]; then
  export JAVA_HOME=$(/usr/libexec/java_home)
  export PATH=~/.bin:/opt/local/bin:/opt/local/sbin:/bin:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/local/mysql/bin:/usr/local/scala/bin
elif [[ `uname -s` == "Linux" ]]; then
  export PATH=~/.bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
fi

alias last='cd $OLDPWD'
alias b='echo -n "sourcing .bashrc... " && source ~/.bashrc && echo "done"'
alias j='jobs'
alias pyunset='unset PYTHONPATH'
alias pypath='echo $PYTHONPATH'
alias jedit='open /Applications/jEdit.app'


# helper functions for working with solr.  because i'm too lazy to remember the urls.
function solr-status() { 
  curl "http://${1}:8080/solr/dataimport?command=status" | python -mjson.tool 
}

function solr-full-import() { 
  curl "http://${1}:8080/solr/dataimport?command=full-import" | python -mjson.tool 
}

function solr-query() { 
  curl "http://${1}:8080/solr/select?${2}" | python -mjson.tool 
}

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

if [ -f ~/.local_bashrc ]; then
  . ~/.local_bashrc
fi
