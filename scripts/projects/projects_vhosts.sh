#!/bin/bash
source .env

PROJECTS="$PROJECTS_LARAVEL $PROJECTS_SYMFONY"

IFS=' ' read -r -a PROJECTS <<< "$PROJECTS"

# Configure satellites
for PROJECT in ${PROJECTS[@]}
do
  if [ ! -f "$PATH_VHOSTS/$PROJECT.conf" ]
  then
    bash $PATH_CONFIGS/_vhost.sh $PROJECT $PATH_VHOSTS
  fi
done

echo "All projects hosted."
