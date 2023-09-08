#!/bin/bash

DOTFILES_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REQUIRED_FILES="$DOTFILES_DIR/required"
DOTFILES_PREFIX="$DOTFILES_DIR/dot_"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

IFS=$'\r\n' GLOBIGNORE='*' command eval 'REQUIRED=($(cat ${REQUIRED_FILES}))'

setup_all() {
    setup_postgres_repo
    upgrade_os_packages
    install_all
    updated_dot_files
    configure_zsh
}

setup_postgres_repo() {
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
}

upgrade_os_packages() {
    sudo apt-get update
    sudo apt-get upgrade -y
} 

configure_dart_repository() {
    test -f /usr/share/keyrings/dart.gpg && return
    echo Setting up dart repo
    wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
    echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
    upgrade_os_packages
}

install_all() {
    install_os_packages 
    install_neovim_plug
    install_github_cli
    install_flutter
    install_vscode
}

install_os_packages() {
    for package in ${REQUIRED[@]}
    do
        apt_install_package $package
    done
}

apt_install_package() {
    package=$1
    echo Installing $package...
    sudo apt-get install -y $package  
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
    configure_dart_repository

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

install_vscode() {
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

    rm -f packages.microsoft.gpg

    upgrade_os_packages

    sudo apt update
    sudo apt install code
}

backup_dot_files() {
    saved_files=()
    for file in `ls $DOTFILES_PREFIX*`
    do
        install_name=$HOME/.${file#"$DOTFILES_PREFIX"}
        install_name=$(echo $install_name | sed "s/__/\//g")
        install_dir=$(dirname $install_name)
        if ! cmp --silent $install_name $file
        then 
            saved_files+=(`basename $file`)
            echo Backing up $file
            cp $install_name $file
        fi
    done
    git commit -am "$TIMESTAMP: backing up ${saved_files[@]}"
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
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
        sudo chsh -s /usr/bin/zsh $USER
    fi
}

OPTIONS='AbdeFGiIVzh'
usage() { 
    echo "usage: $(basename $0) [-$OPTIONS]" 1>&2
    echo "       -A  Setup all"
    echo "       -b  Backup dotfiles to git repo"
    echo "       -d  Update dotfiles from git repo"
    echo "       -e  Install external software"
    echo "       -F  Install flutter"
    echo "       -G  Install GitHub CLI"
    echo "       -i  Install required OS packages"
    echo "       -I  Install all software"
    echo "       -V  Install VSCode"
    echo "       -z  Configure ZSH and install oh-my-zsh"
    echo "       -h  Display this message"
}

# main
while getopts $OPTIONS o; do
    case "${o}" in
        A) setup_all
            ;;
        b) backup_dot_files
            ;;
        d) updated_dot_files
            ;;
        e) install_external_software
            ;;
        F) install_flutter
            ;;
        G) install_github_cli
            ;;
        i) install_os_packages
            ;;
        I) install_all
            ;;
        V) install_vscode
            ;;
        z) configure_zsh
            ;;
        ?|h) usage
            ;;
    esac
done
