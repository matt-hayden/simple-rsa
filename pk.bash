#! /usr/bin/env head
### common functions wrapping openssl public key operations

# Source this file into your script, having implemented pkgen for specific keys.

set -e
source file.bash


function gen() {
	# make sure to implement pkgen
	[[ $1 ]] && private_key="$1" || private_key="$my_private_key"
	[[ $2 ]] && public_key="$2" || public_key="$my_public_key"
	cert="${private_key%.*}.cert"
	public_key="${private_key%.*}.pub"
	secret="${private_key%.*}.secret"
	pkgen "${secret}" "$cert"
	if openssl pkcs8 -topk8 -v2 aes-256-cbc -v2prf hmacWithSHA256 \
		-in "${secret}" \
		-out "$private_key"
	then
		SHRED "${secret}"
	else
		echo Failed to convert "${secret}" to PKCS8 >&2
		exit -1
	fi
	if openssl req -pubkey \
		-in "$cert" \
		-out "$public_key"
	then
		rm -f "$cert"
		echo Public key saved to "$public_key"
	fi
	getQR "${public_key}" "${public_key}.png"
}

function pkpasswd() {
	if [[ "$1" ]]
	then
		private_key="$1"
		shift
	else
		private_key="$my_private_key"
	fi
	echo "Changing password on $private_key" >&2
	openssl pkcs8 -in "$private_key" \
	| openssl pkcs8 -topk8 -v2 aes-256-cbc -v2prf hmacWithSHA256 \
		-out "$private_key"
}

function getQR() {
	# make sure to implement pkexportpub
	[[ -s "$1" ]] && key_file="$1" || key_file="$my_public_key"
	[[ "$2" ]] && img="$2" || img="${key_file%.*}.png"
	pkexportpub "$key_file" | QRENCODE -o "$img"
}

function readQR() {
	# make sure to implement pkimportpub
	img="$1"
	[[ "$2" ]] && key_file="$2" || key_file="${img%.*}.pub"
	shift
	ZBARIMG "$img" | pkimportpub "$key_file"
}

function pkgetsharedsecret() {
	# a binary shared secret is returned on stdout
	their_key="$1"
	shift
	[[ -s "$their_key" ]] || { echo "$their_key" not found; exit -3; }
	openssl pkeyutl -derive -inkey "$my_private_key" -peerkey "$their_key"
}

function pksign() {
	# a binary signature is returned on stdout
	# OpenSSL doesn't seem to sign and verify multiple files correctly, so we instead sign a digest
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -4; }
	if [[ $# -eq 1 ]]
	then
		sig_file="${1}.sig"
		openssl dgst -sha256 -sign "$my_private_key" "${1}" > "$sig_file"
	else
		pkmksum "$@"
	fi
}

function pkmksum() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -5; }
	sha256sum -b "$@" > SHA256SUM
	pksign SHA256SUM
}

function pkchksum() {
	their_key="$1"
	shift
	pkverify "$their_key" SHA256SUM.sig
	sha256sum -cw SHA256SUM
}

function pkverify() {
	their_key="$1"
	shift
	for input_filename
	do
		case "${input_filename}" in
			*.sig)
				sig_file="${input_filename}"
				input_filename="${input_filename%.sig}"
				;;
			*)
				sig_file="${input_filename}.sig"
				;;
		esac
		echo "${input_filename}":
		openssl dgst -sha256 -verify "$their_key" \
			-signature "$sig_file" \
			"$input_filename"
	done
}

function encrypt() {
	# echos back filenames for, say, xargs
	#key_file="aes.key"
	their_key="$1"
	shift

	#[[ -s "$key_file" ]] && mv -b "$key_file" "${key_file}~"
	### use a random string as a session password
	#export secret=$(openssl rand 244)
	#openssl pkeyutl -encrypt \
	#	-pubin -inkey "$their_key" \
	#	-out "$key_file" \
	#	<<< "$secret"
	#echo "$key_file"
	export secret=$(pkgetsharedsecret "$their_key")

	#if [[ "$key_file" -nt session.png ]]
	#then
	#	base64 "$key_file" | QRENCODE -o session.png
	#fi
	if [[ $# -eq 1 ]]
	then
		output_filename=$(_encrypt_files "$1")
		echo "$output_filename"
		sig_file="${output_filename}.sig"
		pksign "$output_filename" > "$sig_file" && echo "$sig_file"
	elif [[ $# -gt 1 ]]
	then
		output_filenames=$(_encrypt_files "$@")
		echo $output_filenames
		sha256sum -b $output_filenames > SHA256SUM
		pksign SHA256SUM > SHA256SUM.sig && echo SHA256SUM{,.sig}
	else
		echo "Bad arguments" >&2
		exit -1
	fi
	export secret=
}


function decrypt() {
	#for input_filename
	#do
	#	case "$input_filename" in
	#		*.key)
	#			key_file="$input_filename"
	#			echo "Using $key_file" >&2
	#			export secret=$(openssl pkeyutl -decrypt -in "$input_filename" -inkey "$my_private_key")
	#			;;
	#	esac
	#done
	their_key="$1"
	shift
	export secret=$(pkgetsharedsecret "$their_key")
	_decrypt_files "$@"
	export secret=
}

