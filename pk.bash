#! /usr/bin/env head
### common functions wrapping openssl public key operations
set -e


function gen() {
	# make sure to implement pkgen
	[[ "$1" ]] && private_key="$1" || private_key="$my_private_key"
	[[ "$2" ]] && public_key="$2" || public_key="$my_public_key"
	cert="${private_key%.*}.cert"
	public_key="${private_key%.*}.pub"
	secret="${private_key%.*}.secret"
	pkgen "${secret}" "$cert" || { echo Failed to generate private key "${secret}"; exit -2; }
	if openssl pkcs8 -topk8 -v2 aes-256-cbc -v2prf hmacWithSHA256 \
		-in "${secret}" \
		-out "$private_key"
	then
		shred "${secret}"
		rm -f "${secret}"
		echo Private key saved to "$private_key"
	else
		echo Failed to convert "${secret}" to PKCS8
	fi
	if openssl req -pubkey \
		-in "$cert" \
		-out "$public_key"
	then
		rm -f "$cert"
		echo Public key saved to "$public_key"
	fi
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

#function pkgetsharedsecret() {
#	# a binary shared secret is returned on stdout
#	their_public_key="$1"
#	shift
#	[[ -s "$their_public_key" ]] || { echo "$their_public_key" not found; exit -2; }
#	openssl pkeyutl -derive -inkey "$my_private_key" -peerkey "$their_public_key"
#}

function pksign() {
	# a binary signature is returned on stdout
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	openssl dgst -sha256 -sign "$my_private_key" "$@"
}

function pkmksum() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	sha256sum -b "$@" > SHA256SUM
	pksign SHA256SUM > SHA256SUM.sig
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

function encrypt() {
	their_public_key="$1"
	shift

	export secret=$(openssl rand 244)
	openssl pkeyutl -encrypt \
		-pubin -inkey "$their_public_key" \
		-out aes.key \
		<<< "$secret"
	pkmksum aes.key "$@"
	echo aes.key
	echo SHA256SUM
	echo SHA256SUM.sig 
	for input_filename
	do
		case "$input_filename" in
			*.7z|*.bz2|*.tbz2|*.gz|*.tgz|*.lzma|*.xz|*.txz|*.tlz|*.zip|*.Z)
				output_filename="${input_filename}.aes"
				function CAT() { pv "$@"; }
				;;
			*.jpg|*.jpeg|*.png)
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
		[[ -s "$output_filename" ]] && echo "$output_filename"
	done
	export secret=
}


function decrypt() {
	for input_filename
	do
		case "$input_filename" in
			*.key)
				export secret=$(openssl pkeyutl -decrypt -in "$input_filename" -inkey "$my_private_key")
				;;
		esac
	done
	for input_filename
	do
		case "$input_filename" in
			*.aes)
				output_filename="${input_filename%.aes}"
				openssl enc -d -aes256 -pass env:secret \
					-in "${input_filename}" \
					-out "$output_filename"
				;;
		esac
	done
	# TODO: verify sums
	secret=
}

