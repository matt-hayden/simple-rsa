#! /usr/bin/env head
### common functions wrapping openssl public key operations

# Source this file into your script, having implemented pkgen for specific keys.

set -e


if command -v shred &> /dev/null
then
	function SHRED() { shred "$@"; rm -f "$@"; }
else
	function SHRED() { rm -f "$@"; }
fi

if command -v trash &> /dev/null
then
	function TRASH() { trash "$@"; }
else
	function TRASH() { rm -i "$@"; }
fi

if command -v qrencode &> /dev/null
then
	function QR() {
		qrencode -c -lH "$@" || echo "No QR code produced" >&2 ;
	}
else
	function QR() { true; }
fi

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
	[[ -s "$1" ]] && from_key="$1" || from_key="$my_public_key"
	[[ "$2" ]] && img="$2" || img="${from_key%.*}.png"
	pkexportpub "$1" | QR -o "$img"
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
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -4; }
	openssl dgst -sha256 -sign "$my_private_key" "$@"
}

function pkmksum() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -5; }
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
	# echos back filenames for, say, zip -@
	their_public_key="$1"
	shift

	# use a random string as a session key.
	export secret=$(openssl rand 244)
	if openssl pkeyutl -encrypt \
		-pubin -inkey "$their_public_key" \
		-out aes.key \
		<<< "$secret"
	then
		echo aes.key
	else
		echo "Key generation failed" >&2
		exit -6
	fi
	base64 aes.key | QR -o session.png
	if pkmksum aes.key "$@"
	then
		echo SHA256SUM{,.sig}
	fi
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
		if CAT "$input_filename" \
		| openssl enc -aes256 -salt -pass env:secret \
			-out "$output_filename"
		then
			if [[ -s "$output_filename" ]]
			then
				echo "$output_filename"
			else
				echo "Encryption failed on $input_filename" >&2
				exit -7
			fi
		fi
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
				if openssl enc -d -aes256 -pass env:secret \
					-in "${input_filename}" \
					-out "$output_filename"
				then
					TRASH "${input_filename}"
				else
					echo "Encryption failed on $input_filename" >&2
					exit -8
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
				echo "$input_filename" ignored
				;;
		esac
	done
		
	# TODO: verify sums
	secret=
}

