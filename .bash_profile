export PS1='\t \h:\W>$ '
export JAVA_HOME=$(/usr/libexec/java_home)
export JAVA_OPTS=-Xmx768m
export PATH=$PATH:~/bin

EMACS='/usr/local/Cellar/emacs/23.3a/bin/emacs'

if [ -f $EMACS ]; then
  alias emacs=$EMACS
fi
