FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

ARG TF_VERSION=1.7.5
ARG YQ_VERSION=v4.42.1

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
  tar \
  unzip \
  util-linux

# Install Terraform
RUN curl -fsSo terraform.zip \
  https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
  unzip terraform.zip && \
  install -Dm755 terraform /usr/bin/terraform

# Install yq, as there are two competing versions and Azure Linux uses the jq wrappers, which breaks the GitHub Workflows
RUN curl -sSfL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64.tar.gz | tar zx && \
  install -Dm755 yq_linux_amd64 /usr/bin/yq && \
  rm -rf yq_linux_amd64.tar.gz yq_linux_amd64 install-man-page.sh yq.1

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
    wheel

COPY . /source

ENV SAP_AUTOMATION_REPO_PATH=/source

WORKDIR /source
