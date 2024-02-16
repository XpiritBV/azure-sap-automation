#!/usr/bin/env bash

function __is_github() {
    if [[ -v GITHUB_CONTEXT ]]; then
        echo "true"
    fi

    echo "false"
}

function __is_devops() {
    if [[ -v SYSTEM_TEAMPROJECT ]] && [[ -v AGENT_NAME ]] && [[ -v AGENT_MACHINE ]] && [[ -v AGENT_ID ]]; then
        echo "true"
    fi

    echo "false"
}

function get_platform() {
    if [[ "$(__is_github)" == "true" ]]; then
        echo "github"
    fi

    if [[ "$(__is_devops)" == "true" ]]; then
        echo "devops"
    fi

    echo "unknown"
}

case $(get_platform) in
github)
    . deploy/scripts/platform/github_functions.sh
    ;;

devops)
    . deploy/scripts/platform/devops_functions.sh
    ;;

*)
    echo -e "${boldred} -- unsupported platform -- ${reset}"
    exit 1
    ;;
esac
}

function set_or_update_key_value() {
  $key=$1
  $value=$2

  var=$(az pipelines variable-group variable list --group-id ${VARIABLE_GROUP_ID} --query "${key}.value")
  if [ -z ${var} ]; then
      az pipelines variable-group variable create --group-id ${VARIABLE_GROUP_ID} --name "${key}" --value ${value} --output none --only-show-errors
  else
      az pipelines variable-group variable update --group-id ${VARIABLE_GROUP_ID} --name "${key}" --value ${value} --output none --only-show-errors
  fi
}

function get_key_value() {
  $key=$1

  var=$(az appconfig kv show -n ${appconfig_name} --key ${key} --label ${variable_group} --query value)

  echo app config key ${key}: ${var}
  return $var
}

function validate_key_value(){
  $key=$1
  $value=$2

  config_value=get_key_value($key)
  if [ $config_value != $value ]; then
    log_warning "The value of ${key} in app config is not the same as the value in the variable group"
  fi
}
