#!/usr/bin/env bash

function exit_error() {
  MESSAGE=$1
  ERROR_CODE=$2

  if [ -z ${GITHUB_CONTEXT} ]; then
    echo "::error::${MESSAGE}"
  else
    echo "##vso[task.logissue type=error]${MESSAGE}"
  fi
  exit $ERROR_CODE
}

function log_warning() {
  MESSAGE=$1

  if [ -z ${GITHUB_CONTEXT} ]; then
    echo "::error::${MESSAGE}"
  else
    echo "##vso[task.logissue type=warning]${MESSAGE}"
  fi
}
