FROM dodasts/submit:8.9.9-el7
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64
ENV OIDC_AGENT=/usr/bin/oidc-agent

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

ENV BASE_CACHE_DIR="/usr/local/share/dodasts/sts-wire/cache"

RUN useradd -u 1001 -g 99 condor_pool && \
    usermod -aG condor condor_pool && \
    mkdir -p ${BASE_CACHE_DIR} && \
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
COPY ./oidc_agent_init_schedd.sh /usr/local/share/dodasts/script/oidc_agent_init.sh
COPY ./post_script_schedd.sh /usr/local/share/dodasts/script/post_script.sh

#RUN yum install -y git \
#    perl-core pcre-devel wget zlib-devel \
#    https://repo.ius.io/ius-release-el7.rpm epel-release centos-release-scl \
#    curl libcurl-devel openssl11-devel rpm-build boost169-devel \
#    && yum clean all \
#    && rm -rf /var/cache/yum
#
#RUN yum install -y devtoolset-11 \
#    && yum clean all \
#    && rm -rf /var/cache/yum
#
#RUN curl -sL https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-x86_64.tar.gz | tar xz --directory=/usr/local --strip-components=1
#
#COPY ./t2u2 /t2u2
#RUN source /opt/rh/devtoolset-11/enable && \
#    cd t2u2 && cmake -S external/yaml-cpp/ -B build_yaml_cpp -DCMAKE_BUILD_TYPE=Debug && \
#    cmake --build build_yaml_cpp && cmake --build build_yaml_cpp -- install && \
#    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBOOST_INCLUDEDIR=/usr/include/boost169 \
#    -DBOOST_LIBRARYDIR=/usr/lib64/boost169 -DOPENSSL_ROOT_DIR=/usr/include/openssl11 \
#    -DOPENSSL_CRYPTO_LIBRARY=/usr/lib64/openssl11/libcrypto.so -DOPENSSL_SSL_LIBRARY=/usr/lib64/openssl11/libssl.so && \
#    cd build && make -j $(nproc) && mkdir -p /etc/t2u2
#
#COPY ./config.yml /etc/t2u2/
