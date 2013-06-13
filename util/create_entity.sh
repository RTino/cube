#!/usr/bin/env bash
#
# Script to create a new entity for the cube
#
# http://cubeapp.io
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>

HOME="../entities/$1"

echo Creating new entity: $1

# Create entity's home directory
mkdir -p $HOME

# Create entity's images directory
mkdir -p ../public/images/$1/archive

# Initialize required files
tar zxfv entity.tar.gz -C $HOME > /dev/null 2>&1

echo Please edit the following files to your needs:
echo $HOME/db.json
echo $HOME/settings.json
echo $HOME/schema.json
