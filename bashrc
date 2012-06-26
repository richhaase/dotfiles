export PS1='\t \u@\h \W>$ '
export JAVA_HOME=$(/usr/libexec/java_home)
export JAVA_OPTS=-Xmx768m
export HADOOP_HOME=/usr/local/hadoop
export PATH=~/.bin:~/.rvm/bin:$HADOOP_HOME/bin:/bin:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/opt/local/bin:/opt/local/sbin
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

set -o vi

alias b='echo -n "sourcing .bashrc... " && source ~/.bashrc && echo "done"'
alias r='cd ~/Dropbox/code/ruby'
alias j='jobs'

function mkproj() {
  mkdir $1
  mkdir $1/{lib,spec,features}
}

function dot() {
  if [[ "x$1" == "x" ]]; then
    echo "usage: dot pull|push \"comment required for push\""
    return 191
  fi
	SAVE=`pwd`
	cd ~/dotfiles
  case $1 in 
    "push" ) 
      if [[ "x$1" == "x" ]]; then
        echo "usage: dot pull|push \"comment required for push\""
        return 192
      else
        git add *
        git commit -am $1
        git push
      fi
      break;;
    "pull" )
	    git pull
	    ./setup.sh
	    source ~/.bash_profile
  esac
	cd $SAVE
}
