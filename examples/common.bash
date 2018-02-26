#! /usr/bin/env bash

# common machinery for decrypt.bash and encrypt.bash
: ${mode?set mode before sourcing}

TMPDIR=$(mktemp -d)
: ${key=key.rsa}
pipe=$(mktemp).pipe
session_key=$(mktemp)

function atexit {
  shred "$session_key"
  rm -rf "$TMPDIR"
}
trap atexit EXIT

if [[ $mode == stdin ]]
then
  mkfifo "$pipe"
  pv > "$pipe" & # consume stdin
fi
