FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

ARG TF_VERSION=1.7.4

RUN tdnf install -y \
  ansible \
  azure-cli \
  ca-certificates \
  curl \
  dotnet-sdk-7.0 \
  dos2unix \
  gawk \
  git \
  gnupg \
  jq \
  openssl-devel \
  openssl-libs \
  powershell \
  python3 \
  python3-pip \
  python3-virtualenv \
  sshpass \
  unzip \
  util-linux \
  zip

# Install Terraform
RUN curl -fsSo terraform.zip \
  https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
  unzip terraform.zip && \
  install -Dm755 terraform /usr/bin/terraform

RUN export LC_ALL="en_US.UTF-8"
RUN export LANG="en_US.UTF-8"

COPY . /source

ENV SAP_AUTOMATION_REPO_PATH=/source

WORKDIR /source
