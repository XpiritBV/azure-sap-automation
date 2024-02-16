#!/usr/bin/env bash

function setup_dependencies() {
    # Nothing here yet.
}

function exit_error() {
    MESSAGE=$1
    ERROR_CODE=$2

    echo "::error::${MESSAGE}"
    exit $ERROR_CODE
}

function log_warning() {
    MESSAGE=$1

    echo "::warning::${MESSAGE}"
}

function start_group() {
    MESSAGE=$1

    echo "::group::${MESSAGE}"
}

function end_group() {
    echo "::endgroup::"
}

function __set_value_with_key() {
    # Nothing here yet.
}

function __get_value_with_key() {
    # Nothing here yet.
}

function __get_value_from_context_with_key() {
    $key=$1

    if [[ $key == "" ]]; then
        exit_error "Cannot get a value by using an empty key"
    fi

    jq_filter="\"${key}\""

    value=$(echo $GITHUB_CONTEXT | jq .'$ENV.jq_filter' )

    echo $value
}

function commit_changes() {
    workflow=$(__get_value_from_context_with_key "github.workflow")

    git config --global user.email github-actions@github.com
    git config --global user.name github-actions
    git commit -m "Added updates from GitHub workflow ${workflow} [skip ci]"
    git push
}

