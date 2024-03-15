FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

ARG TF_VERSION=1.7.4

RUN tdnf install -y \
  ansible \
  azure-cli \
  ca-certificates \
  curl \
  dos2unix \
  dotnet-sdk-7.0 \
  gawk \
  gh \
  git \
  glibc-i18n \
  gnupg \
  jq \
  moreutils \
  openssl-devel \
  openssl-libs \
  powershell \
  python3 \
  python3-pip \
  python3-virtualenv \
  sshpass \
  sudo \
  unzip \
  util-linux \
  zip

# Install Terraform
RUN curl -fsSo terraform.zip \
  https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
  unzip terraform.zip && \
  install -Dm755 terraform /usr/bin/terraform

RUN locale-gen.sh
RUN echo "export LC_ALL=en_US.UTF-8" >> /root/.bashrc && \
    echo "export LANG=en_US.UTF-8" >> /root/.bashrc

RUN pip3 install --upgrade \
    ansible-core \
    argcomplete \
    jmespath \
    netaddr  \
    pip \
    pywinrm \
    setuptools \
    wheel \
    yq

COPY . /source

ENV SAP_AUTOMATION_REPO_PATH=/source

WORKDIR /source
