---
title: Configure GitHub for SAP Deployment Automation Framework
description: Configure your GitHub repository for SAP Deployment Automation Framework.
author: rdeveen
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
>  The GitHub Actions is using Environments to store secrets and variables. Make sure your repository can use the [environments feature](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) and the Issues feature is enabled.

After you created the repository, there will be an Issue created with the title "Create GitHub App". This issue contains the steps to configure a GitHub App for the repository.

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

## Create a new environment issue




# GitHub runner troubleshooting

The GitHub runner is a self-hosted runner that runs the GitHub Actions. If you encounter issues with the runner, you can troubleshoot the runner by following these steps.

- Validate the runner is registered in your repository and is **Online** or **Active** in the `Settings` - `Actions` - `Runners` in the GitHub repository.
- Validate the runner is installed on the VM by validating the output of the VM extension Custom Script named `configure_deployer` in the Azure Portal.
- Validate the


# Cleanup
Delete Azure Resources
Delete GitHub runner
Delete GitHub App
Delete GitHub repository
Delete Entra ID App registration(s)
