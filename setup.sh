#!/bin/bash

BASE=$(dirname $0)
CLEAN_PATHS=( .zshrc .oh-my-zsh .tmux.conf .vimrc .vim )
PATHOGEN_BUNDLES=( https://github.com/Valloric/YouCompleteMe.git \
  https://github.com/vim-airline/vim-airline.git \
  https://github.com/scrooloose/nerdtree.git \
  https://github.com/vim-syntastic/syntastic.git \
  https://github.com/fatih/vim-go.git
)

function setup_homebrew() {
  echo "Install Homebrew"
  if ! which brew
  then
    /usr/bin/ruby -e \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
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
    sh -c "wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -"
  fi

  cp $BASE/zshrc ~/.zshrc
}

function setup_tmux() {
  echo "Install and configure tmux"
  brew install tmux
  gem install tmuxinator

  cp $BASE/tmux.conf ~/.tmux.conf
}
    
function setup_vim() {
  echo "Configure vim"
  brew install macvim
  ln -s /usr/local/bin/mvim /usr/local/bin/vim

  cp $BASE/vimrc ~/.vimrc
  mkdir ~/.vim

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

    if [ $name == 'YouCompleteMe' ]; then
      # YouCompleteMe requires some extra setup
      pushd ~/.vim/bundle/YouCompleteMe
      git submodule update --init --recursive
      ./install.py --clang-completer
      popd
    fi
  done
}

function init() {
  echo "Init"
  echo "===="
  echo
  setup_homebrew
  setup_zsh
  setup_tmux
  setup_vim
}

function update() {
  echo "Update"
  echo "======"
  echo
  brew update
  brew upgrade
  update_pathogen_bundles
  upgrade_oh_my_zsh
}

function clean() {
  echo "Clean"
  echo "====="
  echo
  echo "Are you sure you want to remove all dotfiles? (Y|n): "
  read continue

  if [ $continue == "Y" ]; then
    for path in ${CLEAN_PATHS[@]}; do
      echo "Removing: ~/$path"
      rm -rf ~/$path
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
  *)
    help
    ;;
esac

