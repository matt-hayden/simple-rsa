#! /usr/bin/env head
### common functions wrapping openssl public key operations

# Source this file into your script, having implemented pkgen for specific keys.

set -e
source file.bash


function gen() {
	# make sure to implement pkgen
	[[ "$1" ]] && private_key="$1" || private_key="$my_private_key"
	[[ "$2" ]] && public_key="$2" || public_key="$my_public_key"
	cert="${private_key%.*}.cert"
	public_key="${private_key%.*}.pub"
	secret="${private_key%.*}.secret"
	pkgen "${secret}" "$cert"
	if openssl pkcs8 -topk8 -v2 aes-256-cbc -v2prf hmacWithSHA256 \
		-in "${secret}" \
		-out "$private_key"
	then
		SHRED "${secret}"
		echo Private key saved to "$private_key"
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
	image_file="${public_key}.png"
}

function pkpasswd() {
	if [[ "$1" ]]
	then
		private_key="$1"
		shift
	else
		private_key="$my_private_key"
	fi
	openssl pkcs8 -in "$private_key" \
	| openssl pkcs8 -topk8 -v2 aes-256-cbc -v2prf hmacWithSHA256 \
		-out "$private_key"
}

function getQR() {
	# make sure to implement pkexportpub
	[[ -s "$1" ]] && key_file="$1" || key_file="$my_public_key"
	[[ "$2" ]] && img="$2" || img="${key_file%.*}.png"
	pkexportpub "$key_file" | QR -o "$img"
}

### shared secret derivation is not globally supported by OpenSSL
#function pkgetsharedsecret() {
#	# a binary shared secret is returned on stdout
#	their_public_key="$1"
#	shift
#	[[ -s "$their_public_key" ]] || { echo "$their_public_key" not found; exit -3; }
#	openssl pkeyutl -derive -inkey "$my_private_key" -peerkey "$their_public_key"
#}

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
				sig_file="${input_filename}"
				input_filename="${input_filename%.sig}"
				;;
			*)
				sig_file="${input_filename}.sig"
				;;
		esac
		echo "${input_filename}":
		openssl dgst -sha256 -verify "$their_public_key" \
			-signature "$sig_file" \
			"$input_filename"
	done
}

function encrypt() {
	# echos back filenames for, say, zip -@
	key_file="aes.key"
	their_public_key="$1"
	shift

	# use a random string as a session password
	export secret=$(openssl rand 244)
	openssl pkeyutl -encrypt \
		-pubin -inkey "$their_public_key" \
		-out "$key_file" \
		<<< "$secret"
	echo "$key_file"
	base64 "$key_file" | QR -o session.png
	if [[ $# -gt 1 ]]
	else
		pkmksum "$key_file" "$@"
		echo SHA256SUM{,.sig}
	fi
	for input_filename
	do
		case "$input_filename" in
			*.aes)
				echo "Skipping $input_filename"
				;;
			*.7z|*.bz2|*.tbz2|*.gz|*.tgz|*.lzma|*.xz|*.txz|*.tlz|*.zip|*.Z)
				output_filename="${input_filename}.aes"
				function CAT() { pv "$@"; }
				;;
			*.jpg|*.jpeg|*.png|*.xlsx|*.docx)
				output_filename="${input_filename}.aes"
				function CAT() { pv "$@"; }
				;;
			*.bfe|*.gpg|*.pgp)
				output_filename="${input_filename}.aes"
				function CAT() { pv "$@"; }
				;;
			*)
				output_filename="${input_filename}.gz.aes"
				function CAT() { pv "$@" | gzip -c ; }
				;;
		esac
		CAT "$input_filename" \
		| openssl enc -aes256 -salt -pass env:secret \
			-out "$output_filename"
		echo "$output_filename"
	done
	if [[ $# -eq 1 ]]
	then
		sig_file="${output_filename}.sig"
		pksign "$output_filename" > "$sig_file"
		echo "$sig_file"
	fi
	export secret=
}


function decrypt() {
	for input_filename
	do
		case "$input_filename" in
			*.key)
				key_file="$input_filename"
				echo "Using $key_file" >&2
				export secret=$(openssl pkeyutl -decrypt -in "$input_filename" -inkey "$my_private_key")
				;;
		esac
	done
	[[ "$secret" ]] || { echo "Obtaining key failed"; exit -8; }
	for input_filename
	do
		case "$input_filename" in
			*.aes)
				output_filename="${input_filename%.aes}"
				if openssl enc -d -aes256 -pass env:secret \
					-in "${input_filename}" \
					-out "$output_filename"
				then
					[[ -s "$output_filename" ]] && TRASH "${input_filename}"
				else
					echo "Decryption failed on $input_filename" >&2
				fi
				;;
		esac
	done
	for input_filename
	do
		case "$input_filename" in
			*.aes|*.key)
				;;
			*)
				echo "$input_filename" ignored >&2
				;;
		esac
	done
	export secret=
}

