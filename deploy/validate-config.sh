#!/usr/bin/env bash

# Validate the configuration file has proper keys
# and values for the deployer to start

$config_file=$1

REQUIRED_KEYS=(
  "ARM_SUBSCRIPTION_ID"
  "deployer_random_id"
  "deployer_tfstate_key"
  "keyvault"
  "library_random_id"
  "step"
)

$should_fail=false

for key in "${REQUIRED_KEYS[@]}"; do
  has_key=$(grep "^${key}=" /cfg/$config_file | wc -l)
  if [ $has_key -eq 0 ]; then
    echo "Required key ${key} is missing"
    $should_fail=true
    continue
  fi

  value=$(grep "^${key}=" /cfg/$config_file | cut -d'=' -f2)

  if [ $(echo ${value} | wc -c) -eq 0 ]; then
    echo "Required key ${key} has no value"
    $should_fail=true
  fi
done

if [ $should_fail ]; then
  echo "Configuration file is missing required keys or values"
  exit 1
fi
