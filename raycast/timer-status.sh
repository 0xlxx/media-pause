#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Timer Status
# @raycast.mode compact
# @raycast.icon icon-status.png
# @raycast.packageName Media Timer
# @raycast.description Show running timer progress with elapsed/remaining time

# Optional parameters:
# @raycast.author 0xlxx
# @raycast.keywords timer status progress running check remaining

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

show_status
