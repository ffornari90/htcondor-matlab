# Copyright 2021-2023 The MathWorks, Inc.
# Builds Docker image with 
# 1. MATLAB - Using MPM
# 2. MATLAB Integration for Jupyter
# on a base image of jupyter/base-notebook.

## Sample Build Command:
# docker build --build-arg MATLAB_RELEASE=r2023a \
#              --build-arg MATLAB_PRODUCT_LIST="MATLAB Deep_Learning_Toolbox Symbolic_Math_Toolbox"\
#              --build-arg LICENSE_SERVER=12345@hostname.com \
#              -t my_matlab_image_name .

# Specify release of MATLAB to build. (use lowercase, default is r2023a)
ARG MATLAB_RELEASE=r2023a

# Specify the list of products to install into MATLAB, 
ARG MATLAB_PRODUCT_LIST="MATLAB"

# Optional Network License Server information
ARG LICENSE_SERVER

# If LICENSE_SERVER is provided then SHOULD_USE_LICENSE_SERVER will be set to "_use_lm"
ARG SHOULD_USE_LICENSE_SERVER=${LICENSE_SERVER:+"_with_lm"}

# Default DDUX information
ARG MW_CONTEXT_TAGS=MATLAB_PROXY:JUPYTER:MPM:V1

# Base Jupyter image without LICENSE_SERVER
FROM dodasts/snj-base-lab-persistence:v1.1.1-snj AS base_jupyter_image

# Base Jupyter image with LICENSE_SERVER
FROM dodasts/snj-base-lab-persistence:v1.1.1-snj AS base_jupyter_image_with_lm
ARG LICENSE_SERVER
# If license server information is available, then use it to set environment variable
ENV MLM_LICENSE_FILE=${LICENSE_SERVER}

# Select base Jupyter image based on whether LICENSE_SERVER is provided
FROM base_jupyter_image${SHOULD_USE_LICENSE_SERVER} AS jupyter_matlab
ARG MW_CONTEXT_TAGS
ARG MATLAB_RELEASE
ARG MATLAB_PRODUCT_LIST

# Switch to root user
USER root
ENV DEBIAN_FRONTEND="noninteractive" TZ="Etc/UTC"

## Installing Dependencies for Ubuntu 20.04
# For MATLAB : Get base-dependencies.txt from matlab-deps repository on GitHub
# For mpm : wget, unzip, ca-certificates
# For MATLAB Integration for Jupyter : xvfb
# List of MATLAB Dependencies for Ubuntu 20.04 and specified MATLAB_RELEASE
ARG MATLAB_DEPS_REQUIREMENTS_FILE="https://raw.githubusercontent.com/mathworks-ref-arch/container-images/main/matlab-deps/${MATLAB_RELEASE}/ubuntu20.04/base-dependencies.txt"
ARG MATLAB_DEPS_REQUIREMENTS_FILE_NAME="matlab-deps-${MATLAB_RELEASE}-base-dependencies.txt"

# Install dependencies
RUN wget ${MATLAB_DEPS_REQUIREMENTS_FILE} -O ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} \
    && export DEBIAN_FRONTEND=noninteractive && apt-get update \
    && xargs -a ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME} -r apt-get install --no-install-recommends -y \
    wget \
    unzip \
    ca-certificates \
    xvfb \
    && apt-get clean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* ${MATLAB_DEPS_REQUIREMENTS_FILE_NAME}

# Run mpm to install MATLAB in the target location and delete the mpm installation afterwards
RUN wget -q https://www.mathworks.com/mpm/glnxa64/mpm && \ 
    chmod +x mpm && \
    ./mpm install \
    --release=${MATLAB_RELEASE} \
    --destination=/opt/matlab \
    --products ${MATLAB_PRODUCT_LIST} && \
    rm -f mpm /tmp/mathworks_root.log && \
    ln -s /opt/matlab/bin/matlab /usr/local/bin/matlab

# Install patched glibc - See https://github.com/mathworks/build-glibc-bz-19329-patch
WORKDIR /packages
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && apt-get clean && apt-get autoremove && \
    wget -q https://github.com/mathworks/build-glibc-bz-19329-patch/releases/download/ubuntu-focal/all-packages.tar.gz && \
    tar -x -f all-packages.tar.gz \
    --exclude glibc-*.deb \
    --exclude libc6-dbg*.deb && \
    apt-get install --yes --no-install-recommends --allow-downgrades ./*.deb && \
    rm -fr /packages
WORKDIR /

# Optional: Install MATLAB Engine for Python, if possible. 
# Note: Failure to install does not stop the build.
RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
    && apt-get install --no-install-recommends -y  python3-distutils \
    && apt-get clean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && cd /opt/matlab/extern/engines/python \
    && python setup.py install || true

# Install integration
RUN python3 -m pip install jupyter-matlab-proxy

ENV BASE_CACHE_DIR="/usr/local/share/dodasts/sts-wire/cache"

RUN mkdir -p ${BASE_CACHE_DIR} && \
    mkdir -p /usr/local/share/dodasts/sts-wire/cache && \
    mkdir -p /var/log/sts-wire/ && \
    mkdir -p /s3/ && \
    mkdir -p /s3/scratch

# Switch back to notebook user
RUN groupadd -g 1001 matlabuser && \
    adduser --disabled-password --uid 99 --gid 1001 --gecos '' \
    --home /home/matlabuser --shell /bin/bash matlabuser && \
    chmod -R g+w /s3 && chgrp -R matlabuser /s3 && \
    chmod -R g+w /var/log/sts-wire && chgrp -R matlabuser /var/log/sts-wire && \
    chmod -R g+w /usr/local/share/dodasts/sts-wire && \
    chgrp -R matlabuser /usr/local/share/dodasts/sts-wire

# Install MATLAB HTCondor Plugin
WORKDIR /home/matlabuser/matlab-parallel-htcondor
COPY ./matlab-parallel-htcondor /home/matlabuser/matlab-parallel-htcondor/
COPY ./oidc_agent_job.sub /home/matlabuser/
COPY ./oidc_agent_job.sh /home/matlabuser/
COPY ./htcondor_ca.crt /usr/local/share/ca-certificates/
COPY ./oidc_agent_init.sh /usr/local/share/dodasts/script/
COPY ./install_phantomjs.sh /usr/local/share/dodasts/script/
COPY ./login.js /usr/local/share/dodasts/script/
COPY ./authorize.js /usr/local/share/dodasts/script/
COPY ./run_phantomjs.sh /usr/local/share/dodasts/script/
COPY ./get_access_token.sh /usr/local/share/dodasts/script/
COPY ./condor_init.sh /usr/local/share/dodasts/script/
RUN wget -qO - https://research.cs.wisc.edu/htcondor/ubuntu/HTCondor-Release.gpg.key | apt-key add - && \
    echo "deb https://research.cs.wisc.edu/htcondor/repo/ubuntu/8.9 focal main" >> /etc/apt/sources.list && \
    echo "deb-src https://research.cs.wisc.edu/htcondor/repo/ubuntu/8.9 focal main" >> /etc/apt/sources.list && \
    export DEBIAN_FRONTEND=noninteractive && apt-get update && \
    apt-get install -y oidc-agent cmake libboost-dev libmunge-dev munge libxml2-dev libvirt-dev libcgroup-dev openssh-server \
    libscitokens-dev sqlite3 libsqlite3-dev voms-dev libglobus-gss-assist-dev libglobus-gssapi-gsi-dev openssh-client\
    libglobus-gsi-proxy-core-dev libglobus-gsi-credential-dev libglobus-gsi-callback-dev libglobus-gsi-sysconfig-dev \
    libglobus-gsi-cert-utils-dev libglobus-callout-dev libglobus-common-dev libglobus-gssapi-error-dev libglobus-xio-dev \
    libglobus-io-dev libglobus-rsl-dev libglobus-gass-transfer-dev libglobus-gram-client-dev libglobus-gram-protocol-dev \
    libglobus-rsl-assist-dev libglobus-ftp-client-dev libldap2-dev libglobus-gass-server-ez-dev libboost-python-dev && \
    apt-get clean && apt-get -y autoremove && rm -rf /var/lib/apt/lists/* && \
    cd /opt && wget https://github.com/htcondor/htcondor/archive/refs/tags/V8_9_13.tar.gz && \
    tar xzf V8_9_13.tar.gz && cd htcondor-8_9_13 && mkdir build-cmake && cd build-cmake && \
    cmake .. && make -j $(nproc) && make install && cd /opt && rm -rf htcondor-8_9_13 V8_9_13.tar.gz

RUN /usr/local/share/dodasts/script/install_phantomjs.sh && \
    echo "matlabuser ALL=(ALL) NOPASSWD: /usr/sbin/sshd" >> /etc/sudoers && \
    groupadd -g 119 condor && useradd -u 114 -g 119 condor && \
    useradd condor_pool && usermod -aG condor condor_pool && \
    mkdir -p /etc/condor/config.d && update-ca-certificates && \
    mkdir /data && chown matlabuser:matlabuser -R /data && \
    mkdir /run/sshd && chmod 700 /run/sshd

COPY ./condor_config /etc/condor/
COPY ./01_DODAS_Custom /etc/condor/config.d/

# Make JupyterLab the default environment

ENV JUPYTER_ENABLE_LAB="yes"

ENV MW_CONTEXT_TAGS=${MW_CONTEXT_TAGS}

COPY ./post_script.sh /usr/local/share/dodasts/script/
CMD /usr/local/share/dodasts/script/post_script.sh
RUN chown matlabuser:matlabuser -R /home/matlabuser

USER matlabuser
WORKDIR /s3
