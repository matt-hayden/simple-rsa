#! /usr/bin/env bash
# Simply wrap stdin or args in openssl
set -e
[[ "$@" ]] && mode=files || mode=stdin
source common.bash
: ${private:?missing private key}

openssl pkeyutl -decrypt \
  -keyform PEM -inkey "$private" \
  -in "$key" -out "$session_key"

if [[ $mode == files ]]
then
  parallel openssl enc -d -aes-256-cbc -pass file:"$session_key" -in '{}' -out '{.}' ::: "$@"
else
  openssl enc -d -aes-256-cbc -pass file:"$session_key" -in "$pipe"
fi
