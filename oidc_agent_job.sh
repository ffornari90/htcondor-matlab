#!/bin/bash
export OIDC_CONFIG_DIR="/s3/.oidc-agent"
mkdir -p $OIDC_CONFIG_DIR
cp dodas "$OIDC_CONFIG_DIR"/
env | grep -v '^GROUPS=' > jupyter.env
cp jupyter.env /s3/
