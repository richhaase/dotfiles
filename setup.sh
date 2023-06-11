#!/bin/bash

REQUIRED_FILES='required'
INSTALLED_PACKAGES_FILE='packages'
DOTFILES_PREFIX='dot_'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OPTIONS='deFiIuzh'

touch -a $INSTALLED_PACKAGES_FILE

IFS=$'\r\n' GLOBIGNORE='*' command eval 'REQUIRED=($(cat ${REQUIRED_FILES}))'
IFS=$'\r\n' GLOBIGNORE='*' command eval 'INSTALLED=($(cat ${INSTALLED_PACKAGES_FILE}))'

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

install_flutter() {
    flutter_path=$HOME/flutter
    test -d $flutter_path && return
    echo Installing Flutter
    install_os_packages clang cmake ninja-build pkg-config libgtk-3-dev    
    git clone https://github.com/flutter/flutter.git -b stable $flutter_path
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
    d) 
      updated_dot_files
      ;;
    e) 
      install_external_software
      ;;
    F)
      install_flutter
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
