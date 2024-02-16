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
