export PS1='\t \u@\h \W>$ '
export JAVA_HOME=$(/usr/libexec/java_home)
export JAVA_OPTS=-Xmx768m
export HADOOP_HOME=/usr/local/hadoop
export PATH=~/.bin:~/.rvm/bin:$HADOOP_HOME/bin:/bin:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/opt/local/bin:/opt/local/sbin
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

set -o vi

function mkproj() {
  mkdir $1
  mkdir $1/{lib,spec,features}
}

function refresh() {
	SAVE_DIR=`pwd`
	cd ~/dotfiles
	git pull
	./setup.sh
	source ~/.bash_profile
	cd $SAVE_DIR
}
