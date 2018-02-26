#! /usr/bin/env bash
[[ "$@" ]] && args="$@" || args=~/.ssh/*_rsa
for arg in $args
do
  fn="${arg##*/}"
  ssh-keygen -f "$arg" -e -m PEM > "${fn}.pem"
done
