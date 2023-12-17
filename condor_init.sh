#!/usr/bin/env -S bash -x

check_token() {
  if [ -s "/tmp/condor_token" ]; then
    local current_time=$(date +%s)
    local expiration_time=$(python3 /home/matlabuser/jwt-tools/JWTdecode.py $(cat "/tmp/condor_token") | jq -r '.exp')
    if [ "$expiration_time" -gt "$current_time" ]; then
      return 0
    else
      return 1
    fi
  else
    return 2
  fi
}

directory="/s3/${USERNAME}"

while ! mountpoint "$directory" > /dev/null 2>&1 || [ -z "$(ls -A $directory)" ]; do
    sleep 5
done

ENV_FILE="$directory/condor.env"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' $ENV_FILE | xargs -d '\n')
fi

while true; do
    while ! check_token; do
       /usr/local/share/dodasts/script/get_access_token.sh >/tmp/condor_token
    done
    sleep 600
done &
