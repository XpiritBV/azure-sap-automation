#!/usr/bin/env bash

function exit_error() {
    MESSAGE=$1
    ERROR_CODE=$2

    echo "##vso[task.logissue type=error]${MESSAGE}"
    exit $ERROR_CODE
}

function log_warning() {
    MESSAGE=$1

    echo "[WARNING] ${MESSAGE}"
}

function start_group() {
    MESSAGE=$1
    echo "##[group]${MESSAGE}"
}

function end_group() {
    echo "##[endgroup]"
}

function __set_value_with_key() {
    $key=$1

    value=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "${key}.value")

    if [ -z ${value} ]; then
        az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name $key --value ${file_key_vault} --output none --only-show-errors
    else
        az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name $key --value ${file_key_vault} --output none --only-show-errors
    fi
}

function __get_value_with_key() {
    $key=$1

    value=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "${key}.value")

    echo $value
}
