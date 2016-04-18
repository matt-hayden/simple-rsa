#! /usr/bin/env head
### common functions wrapping openssl public key operations
set -e

PK=./pk-rsa.bash

$PK gen alice.key alice.pub
$PK gen bob.key bob.pub

echo
echo Generating QR code
$PK qr bob.pub

ln -s alice.key .secret_rsa.key
truncate -s 16M foo

echo
echo Testing encryption
$PK encrypt bob.pub foo
$PK verify alice.pub SHA256SUM.sig
