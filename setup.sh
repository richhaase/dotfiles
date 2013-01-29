#!/bin/bash

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATE=`date '+%y%m%d%H%M%S'`

for i in `ls $DIR`; do
	echo $i | egrep -v "#|~|setup.sh" > /dev/null 
	if [ $? == 0 ]; then
		if [ -L ~/.$i ]; then
			echo "REMOVING LINK: ~/.$i"
	   		rm ~/.$i
       	elif [ -e ~/.$i ]; then
	   		echo "SAVING ~/.$i as ~/.${i}_SAVE_$DATE"
	   		mv ~/.$i ~/.${i}_SAVE_$DATE
       	fi
       	echo "LINKING ~/.$i to $DIR/$i"
       	ln -s $DIR/$i ~/.$i
    fi
done
