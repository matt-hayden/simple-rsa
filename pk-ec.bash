#!/usr/bin/env bash
set -e
source pk.bash

curve_name=brainpoolP512r1 # See others with openssl ecparam -list_curves
curve="${curve_name}.curve"
if [[ -s "$curve" ]]
then
	openssl ecparam -in "$curve" -check -noout || exit -1
else
	openssl ecparam -name "$curve_name" -param_enc explicit \
		-out "$curve" \
	&& echo "$curve" can be used with previous versions
fi
my_private_key=.${curve_name}_private.key
my_public_key=public.pem

#[[ -s "$my_private_key" ]] || my_private_key=$HOME/"$my_private_key"
[[ -s "$my_private_key" ]] || echo Running without private key


function pkgen() {
	if [[ "$1" ]]
	then
		private_key="$1"
		shift
	else
		private_key="$my_private_key"
	fi
	[[ -s "$private_key" ]] && { echo Refusing to overwrite "$private_key"; exit -2; }
	# two steps needed to add passphrase, DER format defeats this
	openssl ecparam -genkey -in "$curve" \
	| openssl ec -aes256 -out "$private_key"
}

function pkgetpub() {
	[[ -s "$1" ]] && private_key="$1" || private_key="$my_private_key"
	[[ -s "$private_key" ]] || { echo Cannot find "$private_key"; exit -2; }
	[[ -s "$my_public_key" ]] && mv -f "$my_public_key" "$my_public_key"~
	echo Generating new public key in "$my_public_key"
	openssl ec -pubout \
		-in "$private_key" \
		-out "$my_public_key"
}


case "$1" in
	gen|generate) shift
		pkgen "$@"
		[[ "$my_private_key" -nt "$my_public_key" ]] && pkgetpub
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
	*)
		echo "Invalid command: $@"
		exit -2
		;;
	#
	passwd) shift
		pkpasswd "$@"
		;;
	#
	sig|sign) shift
		pksign "$@"
		[[ "$my_private_key" -nt "$my_public_key" ]] && pkgetpub
		;;
	v|verify) shift
		pkverify "$@"
		;;
	mksum) shift
		pkmksum "$@"
		[[ "$my_private_key" -nt "$my_public_key" ]] && pkgetpub
		;;
	chksum) shift
		pkchksum "$@"
		;;
	*)
		echo "Invalid command: $@"
		exit -2
		;;
esac
