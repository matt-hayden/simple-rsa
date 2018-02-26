#! /usr/bin/env bash
openssl genrsa "$@" | openssl rsa -inform PEM -outform DER
