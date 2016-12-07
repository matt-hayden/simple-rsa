#! /usr/bin/env bash
options='-blowfish -salt -md sha256'

cat << EOP
#! /bin/sh
openssl enc -d $options -a << EOF |
EOP
gzip -c "$@" | openssl enc -e $options -a
echo EOF
echo gzip -d
