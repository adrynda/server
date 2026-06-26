#!/bin/bash

source .env

git pull

ALL_PROJECTS=$(ls $PATH_PROJECTS)

for PROJECT_NAME in $ALL_PROJECTS
do
  pushd "$PATH_PROJECTS/$PROJECT_NAME"
  git pull
  popd
done