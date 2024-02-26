#!/usr/bin/env bash

function __is_github() {
    if [[ -f /tmp/github_context.json ]]; then
        echo "true"
    else
        echo "false"
    fi
}

function __is_devops() {
    if [[ -v SYSTEM_TEAMPROJECT ]] && [[ -v AGENT_NAME ]] && [[ -v AGENT_MACHINE ]] && [[ -v AGENT_ID ]]; then
        echo "true"
    else
        echo "false"
    fi
}

function get_platform() {
    if [[ $(__is_github) == "true" ]]; then
        echo "github"
        return
    fi

    if [[ $(__is_devops) == "true" ]]; then
        echo "devops"
        return
    fi

    echo "unknown"
}

case $(get_platform) in
github)
    . deploy/automation/platform/github_functions.sh
    ;;

devops)
    . deploy/automation/platform/devops_functions.sh
    ;;

*)
    echo -e "${boldred} -- unsupported platform -- ${reset}"
    exit 1
    ;;
esac

function __appconfig_get_value_with_key() {
    key=$1

    var=$(az appconfig kv show -n ${appconfig_name} --key ${key} --label ${variable_group} --query value)

    echo $var
}

function __appconfig_set_value_with_key() {
    key=$1
    value=$2

    var=$(az appconfig kv set -n ${appconfig_name} --key ${key} --label ${variable_group} --value $value)

    echo $var
}

function get_value_with_key() {
    key=$1

    if [[ $key == "" ]]; then
        exit_error "Cannot get value with an empty key" 1
    fi

    if [[ -v appconfig_name ]]; then
        value=$(__appconfig_get_value_with_key $key)
    else
        value=$(__get_value_with_key $key)
    fi

    echo $value
}

function set_value_with_key() {
    key=$1
    value=$2

    if [[ $key == "" ]]; then
        exit_error "Cannot set value with an empty key" 1
    fi

    if [[ -v appconfig_name ]]; then
        __appconfig_set_value_with_key $key $value
    else
        __set_value_with_key $key $value
    fi
}

function validate_key_value() {
    key=$1
    value=$2

    config_value=$(get_value_with_key $key)
    if [ $config_value != $value ]; then
        log_warning "The value of ${key} in app config is not the same as the value in the variable group"
    fi
}

function config_value_with_key() {
    key=$1

    if [[ $key == "" ]]; then
        exit_error "The argument cannot be empty, please supply a key to get the value of" 1
    fi

    echo $(cat ${deployer_environment_file_name} | grep "${key}=" -m1 | awk -F'=' '{print $2}' | xargs)
}

function set_config_key_with_value() {
    key=$1
    value=$2

    if [[ $key == "" ]]; then
        exit_error "The argument cannot be empty, please supply a key to set the value of" 1
    fi

    if grep -q "^$key=" "$deployer_environment_file_name"; then
        sed -i "s/^$key=.*/$key=$value/" "$deployer_environment_file_name"
    else
        echo "$key=$value" >>"$config_file"
    fi
}
