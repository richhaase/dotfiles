#!/bin/bash

BASE=$(dirname $0)
CLEAN_PATHS=( pylintrc zshrc oh-my-zsh tmux.conf vimrc vim )
MACOS_CONFIG_FILES=( pylintrc zshrc tmux.conf vimrc ) 
LINUX_CONFIG_FILES=( zshrc tmux.conf vimrc ) 
PATHOGEN_BUNDLES=( https://github.com/vim-airline/vim-airline.git \
  https://github.com/scrooloose/nerdtree.git \
  https://github.com/tpope/vim-fugitive.git \
  https://github.com/tpope/vim-eunuch.git \
  https://github.com/tpope/vim-endwise.git \
  https://github.com/tpope/vim-markdown.git
)

function sync_cfg_file() {
  echo "Synchronizing $1"
  cp ${BASE}/$1 ~/.$1
}

function setup_homebrew() {
  echo "Install Homebrew"
  if ! which brew
  then
     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi
}

function setup_zsh() {
  echo "Configure zsh"
  # Set zsh as default shell
  if [ $(basename $SHELL) != "zsh" ]
  then
    chsh -S /bin/zsh
  fi

  # Install oh-my-zsh
  if [ ! -d ~/.oh-my-zsh ]
  then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" & 
  fi

  sync_cfg_file zshrc
}

function setup_tmux() {
  echo "Install and configure tmux"

  if ! which tmux
  then
    [[ $(uname -s) == "Darwin" ]] && brew install tmux || sudo apt install tmux
  fi 
  if ! which tmuxinator
  then
    [[ $(uname -s) == "Darwin" ]] && sudo gem install tmuxinator || sudo apt install tmuxinator
  fi

  sync_cfg_file tmux.conf
}
    
function setup_vim() {
  echo "Configure vim"

  [[ ! -f ~/.vimrc ]] && sync_cfg_file vimrc
  [[ ! -d ~/.vim ]] && mkdir ~/.vim

  # install pathogen
  if [ ! -f ~/.vim/autoload/pathogen.vim ]
  then
    mkdir -p ~/.vim/autoload ~/.vim/bundle && \
      curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
  fi

  update_pathogen_bundles
}

function update_pathogen_bundles() {
  for bundle in ${PATHOGEN_BUNDLES[@]}; do
    name=`echo $bundle | awk -F'/' '{print $5}' | sed -e 's/.git//'`
    path=~/.vim/bundle/${name}

    if [ ! -d $path ]; then
      git clone $bundle $path
    else
      pushd $path
      git pull
      popd
    fi
  done
}

function init() {
  echo "Init"
  echo "----"
  echo
  [[ $(uname -s) == "Darwin" ]] && setup_homebrew
  setup_zsh
  if ! which curl
  then 
    [[ $(uname -s) == "Darwin" ]] && sudo brew install curl || sudo apt install curl
  fi
  setup_tmux
  setup_vim
}

function update() {
  echo "Update"
  echo "------"
  echo
  [[ $(uname -s) == "Darwin" ]] && brew update && brew upgrade && upgrade_oh_my_zsh
  update_pathogen_bundles
  sync_cfgs
}

function sync_cfgs() {
  echo "Synchronize Config Files"
  echo "------------------------"
  echo
  for cfg_file in ${CONFIG_FILES[@]}
  do 
    sync_cfg_file ${cfg_file}
  done
}

function clean() {
  echo "Clean"
  echo "-----"
  echo
  echo "Are you sure you want to remove all dotfiles? (Y|n): "
  read continue

  if [ $continue == "Y" ]; then
    for path in ${CLEAN_PATHS[@]}; do
      path="$HOME/.$path"
      if [ -f $path ]; then
        echo "Removing: $path"
        rm -rf $path
      fi
    done
  fi
}

function help() {
  echo "usage: $0 -i|-u|-c"
  echo "  -i initialize/install dotfiles"
  echo "  -u update dotfiles and it's dependencies"
  echo "  -c clean/uninstall all dotfiles"
}

case $1 in 
  '-i')
    init
    ;;
  '-u') 
    update
    ;;
  '-c')
    clean
    ;;
  '-s')
    sync_cfgs
    ;;
  *)
    help
    ;;
esac

