---
title: Configure GitHub for SAP Deployment Automation Framework
description: Configure your GitHub repository for SAP Deployment Automation Framework.
author: rdeveen, cloudcosmonaut
ms.author: kimforss
ms.reviewer: kimforss
ms.date: 21/03/2024
ms.topic: conceptual
ms.service: sap-on-azure
ms.subservice: sap-automation
ms.custom: devx-track-arm-template, devx-track-azurecli
---

# Use SAP Deployment Automation Framework from GitHub

GitHub streamlines the deployment process by providing workflows that you can run to perform the infrastructure deployment and the configuration and SAP installation activities.

You can use GitHub Repos to store your configuration files and use GitHub Actions to deploy and configure the infrastructure and the SAP application.

## Sign up for GitHub

To use SAP Deployment Automation Framework from GitHub, you need to have a GitHub organization and the right permissions to create a repository.

## Create a new GitHub repository

Use the `https://github.com/XpiritBV/azure-sap-automation-deployer` repository template as a starting point for your own repository. Click the [**Use this template**](https://github.com/new?template_name=azure-sap-automation-deployer&template_owner=XpiritBV) button to create a new repository based on the template.

> [!NOTE]
> The GitHub Actions is using Environments to store secrets and variables. Make sure your repository can use the [environments feature](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) and the Issues feature is enabled.

After you created the repository, there will be an Issue created with the title "**Create GitHub App**". This issue contains the steps to configure a GitHub App for the repository.

## Create a GitHub App issue

Before you start creating a deployer, you need to set-up credentials. Let's start with creating a GitHub app, so you can get and set variables and credentials, create and update issues, and register a GitHub runner to deploy the SAP environment.

This app needs the following repository permissions only for **this** repository:
  - Administration: Read & Write (Setting up the GitHub Runner on the deployer VM)
  - contents: Read & Write (Creating configuration files, and update workflow with deployer and library)
  - Environments: Read & Write (Creating environments)
  - Secrets: Read & Write (Used to store secrets in the first step, as there's no App configuration yet)
  - Variables: Read & Write (Used to store variables in the first step, as there's no App configuration yet)
  - Workflows: Read & Write (Creating configuration files, and update workflow with deployer and library)

1. You can use the following link to create the app requirements automagically: https://github.com/settings/apps/new?description=Used%20to%20create%20environments,%20update%20and%20create%20secrets%20and%20variables%20for%20your%20SAP%20on%20Azure%20Setup.&callback=false&request_oauth_on_install=false&public=true&actions=read&administration=write&contents=write&environments=write&issues=write&secrets=write&actions_variables=write&workflows=write&webhook_active=false&events[]=check_run&events[]=check_suite

2. Generate a private key
  - Click on `Generate a private key`
  - Save the private key in the **repository secrets** as  `APPLICATION_PRIVATE_KEY`
  - Save the App ID in the **repository secrets** as `APPLICATION_ID`

3. Install the app on the organization
  - Click on `Install App` and select the organization where you want to deploy the SAP deployment.
  - Select the repository to grant privileges to the app.

  **Note**: If you don't have permissions in your organization, your organization administrator will receive a request to install the app.

When this is done, you can close this issue and new issues using the issue template **create a new environment**.

## Create a new environment

If you want to start to create a new environment to start deploying a deployer, you can do this by creating a new issue on your cloned mirror repository and select the `Create Environment` on tap.

When you open this form, you can enter the name of your environment (e.g. acc, dev, prd, etc. Max 5 characters.),the Azure region you want to deploy to and the VNET your deployer needs to be added to/needs to be created. **note** [more info on the naming convention](https://learn.microsoft.com/en-us/azure/sap/automation/naming).

After you clicked `Submit new issue` a GitHub worklow will be triggered which will create an environment on GitHub to store configuration values and create the configuration file with default settings in your repository. You can look in the `WORKSPACES/DEPLOYER` and `WORKSPACES/LIBRARY`. Depending on your Azure set-up you need to configure this file to make sure the Deployer is using the correct subnet, vnet, private endpoints, etc. **note** [more information about customizing the control plane](https://learn.microsoft.com/en-us/azure/sap/automation/configure-control-plane).

## Set up the web app

The automation framework optionally provisions a web app as a part of the control plane to assist with the SAP workload zone and system configuration files. If you want to use the web app, you must first create an app registration for authentication purposes. Open Azure Cloud Shell and run the following commands.

# [Linux](#tab/linux)

Replace `MGMT` with your environment, as necessary.

```bash
echo '[{"resourceAppId":"00000003-0000-0000-c000-000000000000","resourceAccess":[{"id":"e1fe6dd8-ba31-4d61-89e7-88639da4683d","type":"Scope"}]}]' >> manifest.json

TF_VAR_app_registration_app_id=$(az ad app create --display-name MGMT-webapp-registration --enable-id-token-issuance true --sign-in-audience AzureADMyOrg --required-resource-access @manifest.json --query "appId" | tr -d '"')

echo $TF_VAR_app_registration_app_id

az ad app credential reset --id $TF_VAR_app_registration_app_id --append --query "password"

rm manifest.json
```

# [Windows](#tab/windows)

Replace `MGMT` with your environment, as necessary.

```powershell
Add-Content -Path manifest.json -Value '[{"resourceAppId":"00000003-0000-0000-c000-000000000000","resourceAccess":[{"id":"e1fe6dd8-ba31-4d61-89e7-88639da4683d","type":"Scope"}]}]'

$TF_VAR_app_registration_app_id=(az ad app create --display-name MGMT-webapp-registration --enable-id-token-issuance true --sign-in-audience AzureADMyOrg --required-resource-access .\manifest.json --query "appId").Replace('"',"")

echo $TF_VAR_app_registration_app_id

az ad app credential reset --id $TF_VAR_app_registration_app_id --append --query "password"

del manifest.json
```
---

Save the app registration ID and password values for later use.

# Deploy the Control Plane

The deployment uses the configuration defined in the Terraform variable files located in the /WORKSPACES/DEPLOYER/MGMT-WEEU-DEP00-INFRASTRUCTURE and /WORKSPACES/LIBRARY/MGMT-WEEU-SAP_LIBRARY folders.

1. In the GitHub repository, navigate to the `Actions` tab.
1. Select the `Deploy Control Plane` workflow.
1. Click the `Run workflow` button and select the configuration name for the deployer and the SAP library.

![Run Workflow - Deploy Control Plane](RunWorkflowDeployControlPlane.png)

You can track the progress in the `Actions` tab. After the deployment is finished, you can see the control plane details on the summary output.

## Configure the Web Application authentication issue

If the web app is deployed, you need to configure the web app authentication. The issue  **Configure Web Application authentication** is created and contains the steps to configure the web app authentication.

# GitHub runner troubleshooting

The GitHub runner is a self-hosted runner that runs the GitHub Actions. If you encounter issues with the runner, you can troubleshoot the runner by following these steps.

- Validate the runner is registered in your repository and is **Online** or **Active** in the `Settings` - `Actions` - `Runners` in the GitHub repository.
- Validate the runner is installed on the VM by validating the output of the VM extension Custom Script named `configure_deployer` in the Azure Portal.
- Validate the


# Cleanup
- Delete Azure Resources
- Delete GitHub runner
- Delete GitHub App
- Delete GitHub repository
- Delete Entra ID App registration(s)
