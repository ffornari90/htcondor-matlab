#!/usr/bin/env bash

check_find_dodas() {
  if find /var/lib/condor/spool/ -type f -name "dodas" | grep -q . ; then
    return 0
  else
    return 1
  fi
}

check_find_jupyter() {
  if find /var/lib/condor/spool/ -type f -name "jupyter.env" | grep -q . ; then
    return 0
  else
    return 1
  fi
}

while ! check_find_dodas; do
    sleep 5
done

while ! check_find_jupyter; do
    sleep 5
done

export OIDC_CONFIG_DIR="/s3/.oidc-agent"
mkdir -p "$OIDC_CONFIG_DIR"

cp "$(find /var/lib/condor/spool/ -type f -name 'dodas' | head -n1)" "$OIDC_CONFIG_DIR"/
cp "$(find /var/lib/condor/spool/ -type f -name 'jupyter.env' | head -n1)" /s3/

chown -R condor_pool:nobody "/s3"

su - condor_pool -s /bin/bash -c 'source /usr/local/share/dodasts/script/oidc_agent_init.sh && export BASE_CACHE_DIR="/usr/local/share/dodasts/sts-wire/cache" && umask 0002 && mkdir -p /s3/"${USERNAME}" && sts-wire https://iam.cloud.infn.it/ "${USERNAME}" https://minio.cloud.infn.it/ "/${USERNAME}" "/s3/${USERNAME}" --tryRemount --rcloneMountFlags "--poll-interval 1s" &>"/var/log/sts-wire/mount_log_${USERNAME}.txt"'
