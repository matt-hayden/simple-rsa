#! /usr/bin/env head
### common functions wrapping openssl public key operations
set -e


function pkgetsharedsecret() {
	their_public_key="$1"
	shift
	[[ -s "$their_public_key" ]] || { echo "$their_public_key" not found; exit -2; }
	openssl pkeyutl -derive -inkey "$my_private_key" -peerkey "$their_public_key"
}

function pksign() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	for input_filename
	do
		output_filename="${input_filename}.sig"
		openssl dgst -sha256 -sign $my_private_key \
			-out "${output_filename}" \
			"${input_filename}"
	done
}

function pkmksum() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	sha256sum -b "$@" > SHA256SUM
	[[ -e SHA256SUM.sig ]] && mv -f SHA256SUM.sig SHA256SUM.sig~
	pksign SHA256SUM
}

function pkchksum() {
	their_public_key="$1"
	shift
	pkverify "$their_public_key" "$@" && sha256sum -cw SHA256SUM
}

function pkverify() {
	their_public_key="$1"
	shift
	for input_filename
	do
		case "${input_filename}" in
			*.sig)
				sig_filename="${input_filename}"
				input_filename="${input_filename%.sig}"
				;;
			*)
				sig_filename="${input_filename}.sig"
				;;
		esac
		echo "${input_filename}":
		openssl dgst -sha256 -verify "$their_public_key" \
			-signature "$sig_filename" \
			"$input_filename"
	done
}

function pkpasswd() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	openssl rsa -in "$my_private_key" -aes256 -out tmp.key
	shred "$my_private_key" && mv tmp.key "$my_private_key" || echo Error prevented changing password of "$my_private_key"
}

