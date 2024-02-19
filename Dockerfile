FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

RUN tdnf install -y \
  ansible \
  azure-cli \
  ca-certificates \
  git \
  powershell \
  terraform

COPY . /source

RUN mkdir -p /cfg

ENV SAP_AUTOMATION_REPO_PATH=/source
ENV CONFIG_REPO_PATH=/cfg

WORKDIR /source
