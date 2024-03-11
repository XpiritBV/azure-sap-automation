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

function __get_value_from_context_with_key() {
    key=$1

    if [[ ${key} == "" ]]; then
        exit_error "Cannot get a value by using an empty key"
    fi

    value=$(jq ".${key}" -r /tmp/github_context.json)

    echo $value
}

function commit_changes() {
    message=$1
    is_custom_message=${2:-false}
    workflow=$(__get_value_from_context_with_key "workflow")
    run_number=$(__get_value_from_context_with_key "run_number")
    run_attempt=$(__get_value_from_context_with_key "run_attempt")

    git config --global user.email github-actions@github.com
    git config --global user.name github-actions

    if [[ $is_custom_message == "true" ]]; then
        git commit -m "${message}"
    else
        git commit -m "${message} - Workflow: ${workflow}:${run_number}-${run_attempt} [skip ci]"
    fi

    git push
}

function __get_repository_id() {
    api_url=$(__get_value_from_context_with_key "api_url")
    repository=$(__get_value_from_context_with_key "repository")

    repository_id=$(curl -Ssf \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -L "${api_url}/repos/${repository}" | jq -r '.id')

    echo $repository_id
}

# function __get_environments() {
#     api_url=$(__get_value_from_context_with_key "api_url")
#     repository_id=$(__get_repository_id)

#     curl -Ssf \
#         -H "Accept: application/vnd.github+json" \
#         -H "Authorization: Bearer ${APP_TOKEN}" \
#         -H "X-GitHub-Api-Version: 2022-11-28" \
#         -L "${api_url}/repositories/${repository_id}/environments/${deployerfolder}/variables"
# }

function __create_environment() {
    return 0
    # Nothing here yet.
}

function __get_value_with_key() {
    key=$1

    api_url=$(__get_value_from_context_with_key "api_url")
    repository_id=$(__get_repository_id)

    value=$(curl -Ss \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -L "${api_url}/repositories/${repository_id}/environments/${deployerfolder}/variables/${key}" | jq -r '.value // empty')

    echo $value
}

function __set_value_with_key() {
    key=$1
    value=$2

    api_url=$(__get_value_from_context_with_key "api_url")
    repository_id=$(__get_repository_id)

    if [[ -z $(__get_value_with_key ${key}) ]]; then
        curl -Ss -o /dev/null \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${APP_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -L "${api_url}/repositories/${repository_id}/environments/${deployerfolder}/variables" \
            -d "{\"name\":\"${key}\", \"value\":\"${value}\"}"
    else
        curl -Ss -o /dev/null \
            -X PATCH \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${APP_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -L "${api_url}/repositories/${repository_id}/environments/${deployerfolder}/variables/${key}" \
            -d "{\"name\":\"${key}\", \"value\":\"${value}\"}"
    fi
}

function upload_summary() {
    summary=$1
    echo $summary >> $GITHUB_STEP_SUMMARY
}

function get_runner_registration_token() {
    api_url=$(__get_value_from_context_with_key "api_url")
    repository=$(__get_value_from_context_with_key "repository")

    curl -Ssf \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${APP_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -L "${api_url}/repos/${repository}/actions/runners/registration-token"
}
