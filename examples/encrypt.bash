#! /usr/bin/env bash
# Simply wrap stdin or args in openssl
set -e
[[ "$@" ]] && mode=files || mode=stdin
source common.bash
: ${public:?missing public key}

openssl rand 32 > "$session_key"

openssl pkeyutl -encrypt \
  -keyform PEM -pubin -inkey "$public" \
  -in "$session_key" -out "$key" &

if [[ $mode == files ]]
then
  parallel openssl enc -e -aes-256-cbc -pass file:"$session_key" -in '{}' -out '{}.aes' ::: "$@"
  shred "$@"
  rm "$@"
else
  openssl enc -e -aes-256-cbc -pass file:"$session_key" -in "$pipe"
fi
