#!/bin/bash

DOTFILES_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REQUIRED_FILES="$DOTFILES_DIR/required"
INSTALLED_PACKAGES_FILE="$DOTFILES_DIR/.packages"
DOTFILES_PREFIX="$DOTFILES_DIR/dot_"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OPTIONS='AdeFGiIuzh'

touch -a $INSTALLED_PACKAGES_FILE

IFS=$'\r\n' GLOBIGNORE='*' command eval 'REQUIRED=($(cat ${REQUIRED_FILES}))'
IFS=$'\r\n' GLOBIGNORE='*' command eval 'INSTALLED=($(cat ${INSTALLED_PACKAGES_FILE}))'

setup_all() {
  upgrade_os_packages
  install_all
  updated_dot_files
  configure_zsh
}

upgrade_os_packages() {
  sudo apt-get update
  sudo apt-get upgrade -y
  install_os_packages wget apt-transport-https
  configure_dart_repository
} 

configure_dart_repository() {
  test -f /usr/share/keyrings/dart.gpg && return
  echo Setting up dart repo
  wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
 echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
}

install_all() {
  install_os_packages ${REQUIRED[@]}
  install_neovim_plug
  install_github_cli
  install_flutter
}

install_os_packages() {
  for package in $@
  do
    apt_install_package $package
  done
}

apt_install_package() {
    package=$1
    [[ ${INSTALLED[@]} == *"$package"* ]] && return
    echo Installing $package...
    sudo apt-get install -y $package  
    echo $package >> $INSTALLED_PACKAGES_FILE
}

install_neovim_plug() {
    test -f ~/.local/share/nvim/site/autoload/plug.vim && return
    curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

install_github_cli() {
    test -f /etc/apt/sources.list.d/github-cli.list && return
    echo Installing GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
}

install_flutter() {
    flutter_path=$HOME/flutter
    chrome_pkg_name=google-chrome-stable_current_amd64.deb
    chrome_pkg=$DOTFILES_DIR/$chrome_pkg_name

    install_os_packages clang cmake ninja-build pkg-config libgtk-3-dev    

    ! test $flutter_path && echo Installing Flutter && \
        git clone https://github.com/flutter/flutter.git -b stable $flutter_path
    if [ ! -f $chrome_pkg ]
    then
        echo Downloading $chrome_pkg_name
        wget -P $DOTFILES_DIR https://dl.google.com/linux/direct/$chrome_pkg_name
        apt_install_package $chrome_pkg
    fi
}

updated_dot_files() {
  for file in `ls $DOTFILES_PREFIX*`
  do
    install_name=$HOME/.${file#"$DOTFILES_PREFIX"}
    install_name=$(echo $install_name | sed "s/__/\//g")
    install_dir=$(dirname $install_name)
    [ ! -d $install_dir ] && mkdir -p $install_dir
    if ! cmp --silent $file $install_name
    then 
      echo Updating $install_name
      [[ -f $install_name ]] && mv $install_name $install_name-$TIMESTAMP
      cp $file $install_name
    fi
  done
}

configure_zsh() {
  if [ ! -d $HOME/.oh-my-zsh ]
  then
    echo Setup zsh...
    apt_install_package zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    sudo chsh -s /usr/bin/zsh $USER
  fi
}

usage() { echo "usage: $(basename $0) [-$OPTIONS]" 1>&2; exit 1; }

# main


while getopts $OPTIONS o; do
  case "${o}" in 
    A)
      setup_all
      ;;
    d) 
      updated_dot_files
      ;;
    e) 
      install_external_software
      ;;
    F)
      install_flutter
      ;;
    G) 
      install_github_cli
      ;;
    i)
      install_os_packages
      ;;
    I)
      install_all
      ;;
    u)
      upgrade_os_packages
      ;;
    z)
      configure_zsh
      ;;
    ?|h)
      usage
      ;;
  esac
done
