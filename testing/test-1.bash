#! /usr/bin/env bash

PATH=../examples:"$PATH"

echo "Checking public keys"
[[ -s private.pem ]] || openssl genrsa -out private.pem 1024
[[ -s public.pem ]] || openssl rsa -pubout -in private.pem -out public.pem

echo "Checking command-line utils with args"
date | tee payload-0 > payload-1
public=public.pem encrypt.bash payload-1
mv payload-{1,2}.aes 
private=private.pem decrypt.bash payload-2.aes
diff -q payload-{0,2}

echo "Checking command-line utils with pipes"
public=public.pem encrypt.bash < payload-0 > payload.aes
private=private.pem decrypt.bash < payload.aes > payload-1
diff -q payload-{0,1}
