#!/bin/bash
IAM_CLIENT_SCOPES=${IAM_CLIENT_SCOPES:-"openid profile"}
IAM_TOKEN_ENDPOINT="https://${IAM_SERVER}/token"
IAM_AUTHORIZATION_ENDPOINT="https://${IAM_SERVER}/authorize"
IAM_DASHBOARD_ENDPOINT="https://${IAM_SERVER}/dashboard"
X509_USER_CERT="/s3/${USERNAME}/usercert.pem"
X509_USER_KEY="/s3/${USERNAME}/userkey.pem"
AUTHORIZATION_CODE=$(/usr/local/share/dodasts/script/run_phantomjs.sh $X509_USER_CERT $X509_USER_KEY $IAM_SERVER | awk -F'?' '{print $2}' | tr -d '\r')

curl -s -L \
    --user ${IAM_CLIENT_ID}:${IAM_CLIENT_SECRET} \
    -d grant_type=authorization_code \
    -d "scope=${IAM_CLIENT_SCOPES}" \
    -d "${AUTHORIZATION_CODE}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    ${IAM_TOKEN_ENDPOINT} | jq -r '.access_token'
