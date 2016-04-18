#!/usr/bin/env bash
set -e
source pk.bash

my_private_key=.secret_rsa.key
my_public_key=public.pem

[[ -s "$my_private_key" ]] || echo Running without private key


function pkgen() {
	secret_key="$1"
	[[ -s "$secret_key" ]] && { echo Refusing to overwrite "$secret_key"; exit -1; }
	[[ "$2" ]] && cert="$2" || cert="${secret_key%.*}.cert"
	openssl req -sha256 -nodes -newkey rsa:2048 \
		-keyout "${secret_key}" \
		-out "${cert}"
	[[ -s "$secret_key" ]] || { echo Failed to create "$secret_key"; exit -1; }
}

function pkexportpub() {
	[[ -s "$1" ]] && from_key="$1" || from_key="$my_public_key"
	[[ "$2" ]] && to_key="$2" || to_key="${from_key%.*}.txt"
	openssl rsa -pubin -in "$from_key" -RSAPublicKey_out
}

function pkimportpub() {
	from_key="$1"
	[[ "$2" ]] && to_key="$2" || to_key="${from_key%.*}.pem"
	openssl rsa -RSAPublicKey_in -in "$from_key" -pubout -out "$to_key"
}


case "$1" in
	export) shift
		pkexportpub "$@"
		;;
	gen|generate) shift
		gen "$@"
		;;
	import) shift
		pkimportpub "$@"
		;;
	info) shift
		if [[ -e "$my_private_key" ]]
		then
			echo private:
			ls -l "$my_private_key"
			openssl rsa -text -in "$my_private_key" -noout
		elif [[ -e "$my_public_key" ]]
		then
			echo public:
			ls -l "$my_public_key"
			openssl rsa -text -pubin -in "$my_public_key" -noout
		fi
		;;
	#
	passwd) shift
		pkpasswd "$@"
		;;
	#
	d|decrypt) shift
		decrypt "$@"
		;;
	enc|encrypt) shift
		encrypt "$@"
		;;
	sig|sign) shift
		pksign "$@"
		;;
	v|verify) shift
		pkverify "$@"
		;;
	mksum) shift
		pkmksum "$@"
		;;
	chksum) shift
		pkchksum "$@"
		;;
	qr) shift
		getQR "$@"
		;;
	*)
		echo "Invalid command: $@"
		exit 1
		;;
esac
