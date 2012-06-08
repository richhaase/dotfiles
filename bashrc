export PS1='\t \h:\W>$ '
export JAVA_HOME=$(/usr/libexec/java_home)
export JAVA_OPTS=-Xmx768m
export HADOOP_HOME=/usr/local/hadoop
export PATH=~/.bin:$HADOOP_HOME:~/.rvm/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/opt/local/bin:/opt/local/sbin:/Users/rdh/.rvm/gems/ruby-1.9.3-p125/gems/wukong-2.0.2/bin
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

#rvm docs generate 

function refresh() {
	SAVE_DIR=`pwd`
	cd ~/dotfiles
	git pull
	./setup.sh
	source ~/.bash_profile
	cd $SAVE_DIR
}
