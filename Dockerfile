FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

RUN tdnf install -y \
  ansible \
  azure-cli \
  ca-certificates \
  dos2unix \
  gawk \
  git \
  jq \
  powershell \
  terraform \
  unzip \
  util-linux \
  zip

COPY . /source

ENV SAP_AUTOMATION_REPO_PATH=/source

WORKDIR /source
