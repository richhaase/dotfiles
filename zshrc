# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

ZSH_THEME="daveverwer"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment following line if you want to  shown in the command execution time stamp 
# in the history command output. The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|
# yyyy-mm-dd
 HIST_STAMPS="yyyy-mm-dd"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(brew git mvn tmux tmuxinator)

source $ZSH/oh-my-zsh.sh

# skip history for commands prefixed with space
setopt histignorespace

export EDITOR='vim'
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/sbin:~/bin:~/.bin
export JAVA_HOME="$(/usr/libexec/java_home -v 1.7)"
# golang
export GOPATH=$HOME/src/go
export PATH=$PATH:/usr/local/opt/go/libexec/bin
# Github token
export HOMEBREW_GITHUB_API_TOKEN=`cat ~/.config/homebrew_github_api_token`

function setJava() {
  export JAVA_HOME="$(/usr/libexec/java_home -v $1)"
}

if [ -f ~/.local_zshrc ]; then
  . ~/.local_zshrc
fi

