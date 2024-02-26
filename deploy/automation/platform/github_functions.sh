#!/usr/bin/env bash

function setup_dependencies() {
    git config --global --add safe.directory ${GITHUB_WORKSPACE}

    server_url="$(__get_value_from_context_with_key "server_url")"
    api_url="$(__get_value_from_context_with_key "api_url")"
    repository="$(__get_value_from_context_with_key "repository")"

    echo "TF_VAR_SERVER_URL=${server_url}"
    echo "TF_VAR_API_URL=${api_url}"
    echo "TF_VAR_REPOSITORY=${repository}"

    echo "TF_VAR_APP_TOKEN=${APP_TOKEN}"
    echo "TF_VAR_RUNNER_GROUP=${RUNNER_GROUP}"
}

function exit_error() {
    MESSAGE="$(caller | awk '{print $2":"$1}')$1"
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
    key=$1

    if [[ ${key} == "" ]]; then
        exit_error "Cannot get a value by using an empty key"
    fi

    value=$(jq ".${key}" /tmp/github_context.json)

    echo $value
}

function commit_changes() {
    workflow=$(__get_value_from_context_with_key "workflow")

    git config --global user.email github-actions@github.com
    git config --global user.name github-actions
    git commit -m "Added updates from GitHub workflow ${workflow} [skip ci]"
    git push
}

function __get_repository_id() {
    api_url=$(__get_value_from_context_with_key "api_url")
    repository=$(__get_value_from_context_with_key "repository")

    repository_id=$(curl -SsfL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${api_url}/repos/${repository} | jq '.id')"

    return $repository_id
}

function __get_environments() {
    api_url=$(__get_value_from_context_with_key "api_url")
    repository_id=$(__get_repository_id)

    curl -SsfL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${api_url}/repositories/${repository_id}/environments/${ENVIRONMENT}/variables"
}

function __create_environment() {
    return 0
    # Nothing here yet.
}

function __get_value_with_key() {
    $key=$1

    api_url=$(__get_value_from_context_with_key "api_url")
    repository_id=$(__get_repository_id)

    value=$(curl -SsfL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${api_url}/repositories/${repository_id}/environments/${ENVIRONMENT}/variables/${key}")

    return $value
}

function __set_value_with_key() {
    $key=$1
    $value=$2

    api_url=$(__get_value_from_context_with_key "api_url")
    repository_id=$(__get_repository_id)

    # TODO: Might need a PATCH or PUT
    curl -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${api_url}/repositories/${repository_id}/environments/${ENVIRONMENT}/variables" \
        -d "{\"name\":\"${key}\", \"value\":\"${value}\"}"
}

function upload_summary() {
    summary=$1
    echo $summary >> $GITHUB_STEP_SUMMARY
}

function get_runner_registration_token() {
    api_url=$(__get_value_from_context_with_key "api_url")
    repository=$(__get_value_from_context_with_key "repository")

    curl -SsfL \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${api_url}/repos/${repository}/actions/runners/registration-token"
}
