#!/usr/bin/env -S bash -x

export OIDC_CONFIG_DIR="/s3/.oidc-agent"

export $(cat /s3/jupyter.env | sed 's/#.*//g' | xargs)

export TMPDIR="/tmp"
export HOME="/s3"
export PYTHONPATH="$HOME/.local/lib/python3.6/site-packages"
export OIDC_AGENT=/usr/bin/oidc-agent

cd "$HOME"

git clone https://github.com/federicaagostini/useful-jwt-stuff.git ./jwt-tools

pip install --user pyopenssl==22.0.0
pip install --user -r ./jwt-tools/requirements.txt

check_token() {
  if [ -s "$TMPDIR/token" ]; then
    local current_time=$(date +%s)
    local expiration_time=$(python3 ./jwt-tools/JWTdecode.py $(cat "$TMPDIR/token") | jq -r '.exp')
    if [ "$expiration_time" -gt "$current_time" ]; then
      return 0
    else
      return 1
    fi
  else
    return 2
  fi
}

eval $(oidc-keychain)

while true; do
    oidc-add --pw-cmd "echo \"DUMMY PWD\"" dodas
    if [ $? -eq 0 ]; then
        break
    else
        sleep 1
    fi
done

while true; do
    while ! check_token; do
        oidc-token dodas --time 1200 >"$TMPDIR/token"
    done
    sleep 600
done &
