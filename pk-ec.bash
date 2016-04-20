#!/usr/bin/env bash
set -e
source pk.bash

# OpenSSL elliptic curves can only sign, cannot encrypt

curve_name=secp521r1 # See others with openssl ecparam -list_curves
curve="${curve_name}.curve"
if [[ -s "$curve" ]]
then
	openssl ecparam -in "$curve" -check -noout || exit -1
else
	openssl ecparam -name "$curve_name" -param_enc explicit \
		-out "$curve" \
	&& echo "$curve" can be used with previous versions
fi
my_private_key=.secret_${curve_name}.key
my_public_key=public.pem

[[ -s "$my_private_key" ]] || echo Running without private key


function pkgen() {
	secret_key="$1"
	[[ -s "$secret_key" ]] && { echo Refusing to overwrite "$secret_key"; exit -1; }
	[[ "$2" ]] && cert="$2" || cert="${secret_key%.*}.cert"
	openssl req -config openssl.cnf -sha256 -nodes -newkey ec:"$curve" \
		-keyout "${secret_key}" \
		-out "${cert}"
	[[ -s "$secret_key" ]] || { echo Failed to create "$secret_key"; exit -1; }
}

function pkexportpub() {
	[[ -s "$1" ]] && from_key="$1" || from_key="$my_public_key"
	openssl ec -pubin -in "$from_key"
}

function pkimportpub() {
	key_file="$1"
	[[ -s "$key_file" ]] && { echo "Refusing to overwrite $key_file" >&2 ; exit -1; }
	openssl ec -pubin -out "$key_file"
}


case "$1" in
	gen|generate) shift
		gen "$@"
		;;
	info) shift
		if [[ -e "$my_private_key" ]]
		then
			echo private:
			ls -l "$my_private_key"
			openssl ec -text -in "$my_private_key" -noout
		elif [[ -e "$my_public_key" ]]
		then
			echo public:
			ls -l "$my_public_key"
			openssl ec -text -pubin -in "$my_public_key" -noout
		fi
		;;
	#
	passwd) shift
		pkpasswd "$@"
		;;
	#
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
	getqr) shift
		getQR "$@"
		;;
	readqr) shift
		readQR "$@"
		;;
	*)
		echo "Invalid command: $@"
		exit -2
		;;
esac
