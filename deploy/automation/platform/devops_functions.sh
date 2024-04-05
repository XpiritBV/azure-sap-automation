#!/usr/bin/env bash

function setup_dependencies() {
    az config set extension.use_dynamic_install=yes_without_prompt > /dev/null 2>&1

    az extension add -upgrade --name azure-devops --output none > /dev/null 2>&1

    az devops configure --defaults organization=${System.CollectionUri} project='${System.TeamProject}' --output none > /dev/null 2>&1
    export VARIABLE_GROUP_ID=$(az pipelines variable-group list --q uery "[?name=='${variable_group}'].id | [0]")

    if [ $VARIABLE_GROUP_ID == "" ]; then
        exit_error "Cannot find a variable group with the name ${variable_group}" 1
    fi

    echo "VARIABLE_GROUP_ID=${VARIABLE_GROUP_ID}"
    echo AZURE_DEVOPS_EXT_PAT=${PAT}
    echo deployer=${parent_variable_group{}
}

function exit_error() {
    MESSAGE="$(caller | awk '{print $2":"$1}')$1"
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
    key=$1

    value=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "${key}.value")

    if [ -z ${value} ]; then
        az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name $key --value ${file_key_vault} --output none --only-show-errors
    else
        az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name $key --value ${file_key_vault} --output none --only-show-errors
    fi
}

function __get_value_with_key() {
    key=$1

    value=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "${key}.value")

    echo $value
}

function __set_secret_with_key() {
    key=$1

    value=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "${key}.isSecret")

    if [ -z ${value} ]; then
        az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name $key --secret true --value ${file_key_vault} --output none --only-show-errors
    else
        az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name $key --secret true --value ${file_key_vault} --output none --only-show-errors
    fi
}

function commit_changes() {
    message=$1
    is_custom_message=${2:-false}

    git config --global user.email "${Build.RequestedForEmail}"
    git config --global user.name "${Build.RequestedFor}"

    if [[ $is_custom_message == "true" ]]; then
        git commit -m "${message}"
    else
        git commit -m "${message} - DevOps Build: ${Build.DefinitionName} [skip ci]"\
    fi

    git -c http.extraheader="AUTHORIZATION: bearer ${System_AccessToken}" push --set-upstream origin ${Build.SourceBranchName}
}

function upload_summary() {
    summary=$1

    echo "##vso[task.uploadsummary]${summary}"
}
