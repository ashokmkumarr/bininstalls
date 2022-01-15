#!/bin/bash
echo "Hello, world"
if [ $# != 0 ]
    then
	echo "Arguments present $*"
fi

if [ $# == 0 ]
    then
	echo "No Arguments"
fi
