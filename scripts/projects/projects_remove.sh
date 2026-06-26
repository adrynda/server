#!/bin/bash

source .env

PROJECTS="$PROJECTS_LARAVEL $PROJECTS_SYMFONY"

IFS=' ' read -r -a PROJECTS <<< "$PROJECTS"

# Configure satellites
for PROJECT in ${PROJECTS[@]}
do
  if [ -d "$PATH_PROJECTS/$PROJECT" ]
  then
    rm -rf $PATH_PROJECTS/$PROJECT
  fi
done

echo "All projects removed."
