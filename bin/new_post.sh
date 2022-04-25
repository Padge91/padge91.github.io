#!/bin/bash

# get vars

if [ ! $1 ]
then
	echo "First arg required, pass in the cmd line title of the post." 1>&2
	exit 1
fi

DATE=$(date +"%Y-%m-%d")
DOC_TITLE="$1"
FILE_NAME="../docs/_posts/$DATE-$DOC_TITLE.markdown"


# create file and populate it
touch "$FILE_NAME"
echo "---" > $FILE_NAME
echo "layout: post" >> $FILE_NAME
echo "title: 'Replace Me!'" >> $FILE_NAME
echo "date: '$DATE'" >> $FILE_NAME
echo "categories: general" >> $FILE_NAME
echo "---" >> $FILE_NAME
echo "$FILE_NAME created."
