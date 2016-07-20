#!/usr/bin/env bash

APP_DIR=$(realpath -s `dirname $0`/..)
cd $APP_DIR

CONFIG_FILE=${APP_DIR}/config/stash-migrator.yml
bundle exec stash-harvester -c ${CONFIG_FILE}


