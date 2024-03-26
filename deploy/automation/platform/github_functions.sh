#!/usr/bin/env bash

function setup_dependencies() {
    git config --global --add safe.directory ${GITHUB_WORKSPACE}
}

function exit_error() {
    MESSAGE="$(caller | awk '{print $2":"$1} ') $1"
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

function commit_changes() {
    message=$1
    is_custom_message=${2:-false}

    git config --global user.email github-actions@github.com
    git config --global user.name github-actions

    if [[ $is_custom_message == "true" ]]; then
        git commit -m "${message}"
    else
        git commit -m "${message} - Workflow: ${GITHUB_WORKFLOW}:${GITHUB_RUN_NUMBER}-${GITHUB_RUN_ATTEMPT} [skip ci]"
    fi

    git push
}

function __get_value_with_key() {
    key=$1

    value=$(curl -Ss \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -L "${GITHUB_API_URL}/repositories/${GITHUB_REPOSITORY_ID}/environments/${deployerfolder}/variables/${key}" | jq -r '.value // empty')

    echo $value
}

function __set_value_with_key() {
    key=$1
    new_value=$2

    old_value=$(__get_value_with_key ${key})

    echo "Saving value for key in environment ${deployerfolder}: ${key}"

    if [[ -z "${old_value}" ]]; then
        curl -Ss -o /dev/null \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${APP_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -L "${GITHUB_API_URL}/repositories/${GITHUB_REPOSITORY_ID}/environments/${deployerfolder}/variables" \
            -d "{\"name\":\"${key}\", \"value\":\"${new_value}\"}"
    elif [[ "${old_value}" != "${new_value}" ]]; then
        curl -Ss -o /dev/null \
            -X PATCH \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${APP_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -L "${GITHUB_API_URL}/repositories/${GITHUB_REPOSITORY_ID}/environments/${deployerfolder}/variables/${key}" \
            -d "{\"name\":\"${key}\", \"value\":\"${new_value}\"}"
    fi
}

function upload_summary() {
    summary=$1
    if [[ -f $GITHUB_STEP_SUMMARY ]]; then
        cat $summary >> $GITHUB_STEP_SUMMARY
    else
        echo $summary >> $GITHUB_STEP_SUMMARY
    fi
}
