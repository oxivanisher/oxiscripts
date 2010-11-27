#!/bin/bash

SRCPATH=$HOME/Desktop/abc
TRGPATH=$HOME/Desktop/new_abc

mkdir -p $TRGPATH

FILECNT=0
LINECNT=0

for MYFILE in `ls $SRCPATH`;
do
	echo -e "processing file: $MYFILE"
	FILECNT=`cat $FILECNT + 1`

	while read $MYFILE;
	do
		LINECNT=`expr $LINECNT + 1`

	done
done

echo -e "processed $FILECNT files and $LINECNT lines."
