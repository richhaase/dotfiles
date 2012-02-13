#!/bin/bash                                                                                                                       

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATE=`date '+%y%m%d%H%M%S'`

function link () {
    echo $3
    ln -s $1 $2
}

function rm_link () {
    rm ~/.$1
    link $DIR/$i ~/.$i "COMPLETE W/ REMOVED LINK"   
}

for i in "emacs" "emacs.d"; do
    echo -n "SETTING UP .emacs: "
    if [ -f ~/.$i ]; then
	mv ~/.$i ~/.${i}_$DATE
	link $DIR/$i ~/.$i "COMPLETE W/ BACKUP"
    elif [ -d ~/.$i ]; then
	rm_link ~/.$i
    elif [ -L ~/.$i ]; then
	rm_link ~/.$i
    else
	link $DIR/$i ~/.$i "COMPLETE"
    fi
done

