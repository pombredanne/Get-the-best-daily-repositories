#!/bin/bash

source .env

export ENVIRONMENT=$ENVIRONMENT
export RPC_URL=$RPC_URL
export PHX_HOST=$PHX_HOST
export DB_NAME=$DB_NAME
export DB_USER=$DB_USER
export DB_PASS=$DB_PASS
export DB_HOST=$DB_HOST
export ALIGNED_CONFIG_FILE=$ALIGNED_CONFIG_FILE

mix deps.get

mix compile --force #force recompile to get the latest .env values

mix ecto.create
mix ecto.migrate
