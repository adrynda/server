#!/bin/bash

./scripts/docker/down.sh
(
  cd _infrastructure
  docker compose up -d
)