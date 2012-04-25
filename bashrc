export PS1='\t \h:\W>$ '
export JAVA_HOME=$(/usr/libexec/java_home)
export JAVA_OPTS=-Xmx768m
export PATH=$PATH:~/.bin:/usr/local/hadoop/bin:~/.rvm/bin:/Library/Ruby/Gems/1.8/gems/wukong-2.0.2/bin:/Users/rdh/.rvm/gems/ruby-1.9.3-p125/gems/wukong-2.0.2/bin
export HADOOP_HOME=/usr/local/hadoop

. ~/.bashrc 

#rvm docs generate 

function refresh() {
	SAVE_DIR=`pwd`
	cd ~/dotfiles
	git pull
	./setup.sh
	source ~/.bash_profile
	cd $SAVE_DIR
}
