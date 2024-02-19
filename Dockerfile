FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

RUN tdnf install -y \
  ansible \
  azure-cli \
  ca-certificates \
  gawk \
  git \
  powershell \
  terraform \
  zip \
  unzip \
  dos2unix

COPY . /source

ENV SAP_AUTOMATION_REPO_PATH=/source

WORKDIR /source
