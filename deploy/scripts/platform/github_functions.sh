#!/usr/bin/env bash

function setup_dependencies() {
    git config --global --add safe.directory ${GITHUB_WORKSPACE}
    org_url="$(__get_value_from_context_with_key "github.server_url")/$(__get_value_from_context_with_key "github.organization")"

    echo "TF_VAR_APP_TOKEN=${APP_TOKEN}"
    echo "TF_VAR_RUNNER_GROUP=${RUNNER_GROUP}"
    echo "TF_VAR_ORG_URL=${org_url}"
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

function __get_repository_id() {
    repository=$(__get_value_from_context_with_key "github.repository")

    repository_id=$(curl -SsfL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/${repository} | jq '.id')

    return $repository_id
}

function __get_environments() {
    repository_id=$(__get_repository_id)

    curl -SsfL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repositories/${repository_id}/environments/${ENVIRONMENT}/variables
}

function __create_environment() {
    return 0
    # Nothing here yet.
}

function __get_value_with_key() {
    $key=$1

    repository_id=$(__get_repository_id)

    value=$(curl -SsfL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repositories/${repository_id}/environments/${ENVIRONMENT}/variables/${key})

    return $value
}

function __set_value_with_key() {
    $key=$1
    $value=$2

    repository_id=$(__get_repository_id)

    # TODO: Might need a PATCH or PUT
    curl -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repositories/${repository}/environments/${ENVIRONMENT}/variables \
        -d "{\"name\":\"${key}\", \"value\":\"${value}\"}"
}
