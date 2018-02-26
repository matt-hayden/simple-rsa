#! /usr/bin/env bash
[[ "$@" ]] && args="$@" || args=~/.ssh/*.pub

for arg in $args
do
  fp="${arg%.pub}"
  if [[ -e "${fp}-cert.pub" ]]
  then
    echo "Skipping $arg"
  fi
  fn="${arg##*/}"
  if ssh-keygen -f "$arg" -e -m PEM | openssl rsa -RSAPublicKey_in -out "${fn}.pem"
  then
    echo "$arg succeeded" 
  fi
done
