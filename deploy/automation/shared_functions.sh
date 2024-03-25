#!/usr/bin/env bash

function __is_github() {
    if [[ -v GITHUB_ACTIONS ]]; then
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
    . ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/platform/github_functions.sh
    ;;

devops)
    . ${SAP_AUTOMATION_REPO_PATH}/deploy/automation/platform/devops_functions.sh
    ;;

*)
    echo -e "${boldred} -- unsupported platform -- ${reset}"
    exit 1
    ;;
esac

function __appconfig_get_value_with_key() {
    key=$1

    var=$(az appconfig kv show -n ${APP_CONFIGURATION_NAME} --key ${key} --label ${VARIABLE_GROUP_ID} --query value --output tsv)

    echo $var
}

function __appconfig_set_value_with_key() {
    key=$1
    value=$2

    echo "Saving value for key in ${APP_CONFIGURATION_NAME}: ${key}"
    var=$(az appconfig kv set -n ${APP_CONFIGURATION_NAME} --key ${key} --label ${VARIABLE_GROUP_ID} --value ${value} --content-type text/plain --yes)

    echo $var
}

function __appconfig_get_secret_with_key() {
    key=$1

    var=$(az appconfig kv show -n ${APP_CONFIGURATION_NAME} --key ${key} --label ${VARIABLE_GROUP_ID} --query value --secret --output tsv)

    echo $var
}

function get_value_with_key() {
    key=$1

    if [[ $key == "" ]]; then
        exit_error "Cannot get value with an empty key" 1
    fi

    if [[ -v APP_CONFIGURATION_NAME ]]; then
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

    if [[ -v APP_CONFIGURATION_NAME ]]; then
        __appconfig_set_value_with_key $key $value
    else
        __set_value_with_key $key $value
    fi
}

function get_secret_with_key() {
    key=$1

    if [[ $key == "" ]]; then
        exit_error "Cannot get secret with an empty key" 1
    fi

    if [[ -v APP_CONFIGURATION_NAME ]]; then
        value=$(__appconfig_get_secret_with_key $key)
    else
        value=$(__set_secret_with_key $key)
    fi

    echo $value
}

function set_secret_with_key() {
    key=$1
    value=$2

    if [[ $key == "" ]]; then
        exit_error "Cannot set secret with an empty key" 1
    fi

    if [[ -v APP_CONFIGURATION_NAME ]]; then
        __appconfig_set_secret_with_key $key $value
    else
        __set_secret_with_key $key $value
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
    config_file_name=${2:-$deployer_environment_file_name}

    if [[ $key == "" ]]; then
        exit_error "The argument cannot be empty, please supply a key to get the value of" 1
    fi

    echo $(cat ${config_file_name} | grep "${key}=" -m1 | awk -F'=' '{print $2}' | xargs)
}

function set_config_key_with_value() {
    key=$1
    value=$2
    config_file_name=${3:-$deployer_environment_file_name}

    if [[ $key == "" ]]; then
        exit_error "The argument cannot be empty, please supply a key to set the value of" 1
    fi

    if grep -q "^$key=" "$config_file_name"; then
        sed -i "s/^$key=.*/$key=$value/" "$config_file_name"
    else
       echo "$key=$value" >>"$config_file_name"
    fi
}

function region_with_region_map() {
    LOCATION_CODE=$1

    if [[ $LOCATION_CODE == "" ]]; then
        exit_error "The argument cannot be empty, please supply a region code" 1
    fi

    case $LOCATION_CODE in
        "AUCE") LOCATION_IN_FILENAME="australiacentral" ;;
        "AUC2") LOCATION_IN_FILENAME="australiacentral2" ;;
        "AUEA") LOCATION_IN_FILENAME="australiaeast" ;;
        "AUSE") LOCATION_IN_FILENAME="australiasoutheast" ;;
        "BRSO") LOCATION_IN_FILENAME="brazilsouth" ;;
        "BRSE") LOCATION_IN_FILENAME="brazilsoutheast" ;;
        "BRUS") LOCATION_IN_FILENAME="brazilus" ;;
        "CACE") LOCATION_IN_FILENAME="canadacentral" ;;
        "CAEA") LOCATION_IN_FILENAME="canadaeast" ;;
        "CEIN") LOCATION_IN_FILENAME="centralindia" ;;
        "CEUS") LOCATION_IN_FILENAME="centralus" ;;
        "CEUA") LOCATION_IN_FILENAME="centraluseuap" ;;
        "EAAS") LOCATION_IN_FILENAME="eastasia" ;;
        "EAUS") LOCATION_IN_FILENAME="eastus" ;;
        "EUSA") LOCATION_IN_FILENAME="eastus2euap" ;;
        "EUS2") LOCATION_IN_FILENAME="eastus2" ;;
        "EUSG") LOCATION_IN_FILENAME="eastusstg" ;;
        "FRCE") LOCATION_IN_FILENAME="francecentral" ;;
        "FRSO") LOCATION_IN_FILENAME="francesouth" ;;
        "GENO") LOCATION_IN_FILENAME="germanynorth" ;;
        "GEWE") LOCATION_IN_FILENAME="germanywest" ;;
        "GEWC") LOCATION_IN_FILENAME="germanywestcentral" ;;
        "ISCE") LOCATION_IN_FILENAME="israelcentral" ;;
        "ITNO") LOCATION_IN_FILENAME="italynorth" ;;
        "JAEA") LOCATION_IN_FILENAME="japaneast" ;;
        "JAWE") LOCATION_IN_FILENAME="japanwest" ;;
        "JINC") LOCATION_IN_FILENAME="jioindiacentral" ;;
        "JINW") LOCATION_IN_FILENAME="jioindiawest" ;;
        "KOCE") LOCATION_IN_FILENAME="koreacentral" ;;
        "KOSO") LOCATION_IN_FILENAME="koreasouth" ;;
        "NCUS") LOCATION_IN_FILENAME="northcentralus" ;;
        "NOEU") LOCATION_IN_FILENAME="northeurope" ;;
        "NOEA") LOCATION_IN_FILENAME="norwayeast" ;;
        "NOWE") LOCATION_IN_FILENAME="norwaywest" ;;
        "PLCE") LOCATION_IN_FILENAME="polandcentral" ;;
        "QACE") LOCATION_IN_FILENAME="qatarcentral" ;;
        "SANO") LOCATION_IN_FILENAME="southafricanorth" ;;
        "SAWE") LOCATION_IN_FILENAME="southafricawest" ;;
        "SCUS") LOCATION_IN_FILENAME="southcentralus" ;;
        "SCUG") LOCATION_IN_FILENAME="southcentralusstg" ;;
        "SOEA") LOCATION_IN_FILENAME="southeastasia" ;;
        "SOIN") LOCATION_IN_FILENAME="southindia" ;;
        "SECE") LOCATION_IN_FILENAME="swedencentral" ;;
        "SWNO") LOCATION_IN_FILENAME="switzerlandnorth" ;;
        "SWWE") LOCATION_IN_FILENAME="switzerlandwest" ;;
        "UACE") LOCATION_IN_FILENAME="uaecentral" ;;
        "UANO") LOCATION_IN_FILENAME="uaenorth" ;;
        "UKSO") LOCATION_IN_FILENAME="uksouth" ;;
        "UKWE") LOCATION_IN_FILENAME="ukwest" ;;
        "WCUS") LOCATION_IN_FILENAME="westcentralus" ;;
        "WEEU") LOCATION_IN_FILENAME="westeurope" ;;
        "WEIN") LOCATION_IN_FILENAME="westindia" ;;
        "WEUS") LOCATION_IN_FILENAME="westus" ;;
        "WUS2") LOCATION_IN_FILENAME="westus2" ;;
        "WUS3") LOCATION_IN_FILENAME="westus3" ;;
        *) LOCATION_IN_FILENAME="westeurope" ;;
    esac

    echo $LOCATION_IN_FILENAME
}
