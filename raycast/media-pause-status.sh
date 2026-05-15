#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Pause Status
# @raycast.mode compact
# @raycast.icon icon-status.png
# @raycast.packageName Media Tools
# @raycast.description Show running timer progress with elapsed/remaining time

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords status timer progress running check

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

show_status
