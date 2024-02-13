#!/usr/bin/env bash

function exit_error() {
  MESSAGE=$1
  ERROR_CODE=$2

  if [[ -v GITHUB_CONTEXT ]]; then
    echo "::error::${MESSAGE}"
  else
    echo "##vso[task.logissue type=error]${MESSAGE}"
  fi
  exit $ERROR_CODE
}

function log_warning() {
  MESSAGE=$1

  if [[ -v GITHUB_CONTEXT ]]; then
    echo "::warning::${MESSAGE}"
  else
    echo "##vso[task.logissue type=warning]${MESSAGE}"
  fi
}

function start_group() {
  MESSAGE=$1

  if [[ -v GITHUB_CONTEXT ]]; then
    echo "::group::${MESSAGE}"
  else
    echo "##[group]${MESSAGE}"
  fi
}

function end_group() {
  if [[ -v GITHUB_CONTEXT ]]; then
    echo "::endgroup::"
  else
    echo "##[endgroup]"
  fi
}

function set_or_update_key_value() {
  $key=$1
  $value=$2

  var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "${key}.value")
  if [ -z ${var} ]; then
      az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name "${key}" --value ${value} --output none --only-show-errors
  else
      az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name "${key}" --value ${value} --output none --only-show-errors
  fi
}
