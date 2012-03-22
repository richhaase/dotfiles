#!/usr/bin/env bash
if [ -d ~/"Library/Application Support/TextMate/Bundles/" ];then
	echo "Nothing to do. Exiting."
else
	echo "adding pig syntax highlighting to TextMate"
	mkdir -p ~/"Library/Application Support/TextMate/Bundles/"
	cd ~/"Library/Application Support/TextMate/Bundles/"
	git clone git://github.com/kevinweil/pig.tmbundle "Pig.tmbundle"
	osascript -e 'tell app "TextMate" to reload bundles'
fi