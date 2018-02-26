#! /usr/bin/env bash

# common machinery for decrypt.bash and encrypt.bash
: ${mode?set mode before sourcing}

TMPDIR=$(mktemp -d)
: ${key=key.rsa}
pipe=$(mktemp)
session_key=$(mktemp)

function atexit {
  shred "$session_key"
  [[ -p "$pipe" ]] || shred "$pipe"
  rm -rf "$TMPDIR"
}
trap atexit EXIT

if [[ $mode == stdin ]]
then
  ### couldn't get these to work:
  #mkfifo "$pipe"
  #cat > "$pipe" & # consume stdin
  pv -b > "$pipe"
fi
