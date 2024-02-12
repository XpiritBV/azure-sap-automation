#!/usr/bin/env bash

function exit_error() {
  MESSAGE=$1
  ERROR_CODE=$2

  if [[ -v ${GITHUB_CONTEXT} ]]; then
    echo "::error::${MESSAGE}"
  else
    echo "##vso[task.logissue type=error]${MESSAGE}"
  fi
  exit $ERROR_CODE
}

function log_warning() {
  MESSAGE=$1

  if [[ -v ${GITHUB_CONTEXT} ]]; then
    echo "::warning::${MESSAGE}"
  else
    echo "##vso[task.logissue type=warning]${MESSAGE}"
  fi
}

function start_group() {
  MESSAGE=$1

  if [[ -v ${GITHUB_CONTEXT} ]]; then
    echo "::group::${MESSAGE}"
  else
    echo "##[group]${MESSAGE}"
  fi
}

function end_group() {
  if [[ -v ${GITHUB_CONTEXT} ]]; then
    echo "::endgroup::"
  else
    echo "##[endgroup]"
  fi
}
