#!/bin/bash

source .env

IFS=' ' read -r -a PROJECTS_LARAVEL <<< "$PROJECTS_LARAVEL"
IFS=' ' read -r -a PROJECTS_SYMFONY <<< "$PROJECTS_SYMFONY"

# Configure
for PROJECT in ${PROJECTS_LARAVEL[@]}
do
  bash $PATH_CONFIGS/_laravel.sh $CONTAINER_PHP $PROJECT
done

for PROJECT in ${PROJECTS_SYMFONY[@]}
do
  bash $PATH_CONFIGS/_symfony.sh $CONTAINER_PHP $PROJECT
done

docker exec $CONTAINER_PHP sh -c "chmod -R a+w ./"

echo "All projects installed."
