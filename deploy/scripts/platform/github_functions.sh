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
