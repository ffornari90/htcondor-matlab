FROM htcondor/execute:8.9.9-el7

RUN yum install -y python36 python36-devel python36-pip jq git fuse && yum clean all

# Make dodasts, script and bin folders
RUN mkdir -p /usr/local/share/dodasts /usr/local/share/dodasts/script /usr/local/share/dodasts/bin \
    && python3 -m pip install  --no-cache-dir -U pip==21.3.1 setuptools==59.6.0 wheel==0.37.1

# Install sts-wire
RUN curl -L https://github.com/DODAS-TS/sts-wire/releases/download/v2.1.2/sts-wire_linux -o /usr/local/share/dodasts/bin/sts-wire && \
    chmod +x /usr/local/share/dodasts/bin/sts-wire && \
    ln -s /usr/local/share/dodasts/bin/sts-wire /usr/local/bin/sts-wire

# Install oidc-agent
RUN curl -L https://repo.data.kit.edu/data-kit-edu-centos7.repo -o /etc/yum.repos.d/data-kit-edu-centos7.repo && \
    yum install -y oidc-agent && yum clean all

RUN yum install -y libXt && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    userdel -r slot2 && \
    useradd -u 1001 -g 99 condor_pool && \
    usermod -aG condor condor_pool && \
    wget https://www.mathworks.com/mpm/glnxa64/mpm && \
    chmod +x mpm && mkdir -p /opt/matlab/R2023a/licenses && \
    ./mpm install --release=R2023a --destination=/opt/matlab/R2023a/ \
    --products MATLAB MATLAB_Parallel_Server Parallel_Computing_Toolbox

ENV BASE_CACHE_DIR="/usr/local/share/dodasts/sts-wire/cache"

RUN mkdir -p ${BASE_CACHE_DIR} && \
    mkdir -p /usr/local/share/dodasts/sts-wire/cache && \
    mkdir -p /var/log/sts-wire/ && \
    mkdir -p /s3/ && \
    mkdir -p /s3/scratch && \
    chmod -R g+w /s3 && \
    chgrp -R nobody /s3 && \
    chown -R condor_pool /s3 && \
    chmod -R g+w /var/log/sts-wire && \
    chgrp -R nobody /var/log/sts-wire && \
    chown -R condor_pool /var/log/sts-wire && \
    chmod -R g+w /usr/local/share/dodasts/sts-wire && \
    chgrp -R nobody /usr/local/share/dodasts/sts-wire && \
    chown -R condor_pool /usr/local/share/dodasts/sts-wire && \
    ln -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    /etc/ssl/certs/ca-certificates.crt

COPY ./supervisord.conf /etc/
COPY ./oidc_agent_init_wn.sh /usr/local/share/dodasts/script/oidc_agent_init.sh
COPY ./post_script_wn.sh /usr/local/share/dodasts/script/post_script.sh
COPY ./network.lic /opt/matlab/R2023a/licenses/
