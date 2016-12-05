#! /usr/bin/env head
### Source this file into your script

set -e

cipher='-aes-128-ctr'

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
	function QRENCODE() {
		qrencode -c -lH "$@" || echo "No QR code produced" >&2
	}
else
	function QRENCODE() { true; }
fi

if command -v zbarimg &> /dev/null
then
	function ZBARIMG() {
		zbarimg --raw -q "$@"
	}
else
	function ZBARIMG() { true; }
fi

function _encrypt_in() {
	[[ "$secret" ]] || { echo "Obtaining key failed" >&2 ; exit -9; }
	if [[ $1 ]]
	then
		output_filename="${1%.aes}.aes"
	else
		output_filename="out.xz.aes"
	fi
	if [[ -s "$output_filename" ]]
	then
		echo "Refusing to overwrite $output_filename" >&2
		exit -1
	fi
	case "$output_filename" in
		*.gz.*)
			gzip
			;;
		*.xz.*)
			xz -C sha256
			;;
		*)
			pv
			;;
	esac | openssl enc $cipher -salt -pass env:secret \
		-out "$output_filename"
	if [[ -s "$output_filename" ]]
	then
		echo "$output_filename"
	else
		echo Encryption failed >&2
		exit -1
	fi
}

function _encrypt_files() {
	[[ "$secret" ]] || { echo "Obtaining key failed"; exit -9; }
	for input_filename
	do
		case "$input_filename" in
			*.sig)
				echo "Skipping $input_filename" >&2
				continue
				;;
			-)
				_encrypt_in
				continue
				;;
			*.7z|*.bz2|*.tbz2|*.gz|*.tgz|*.lzma|*.xz|*.txz|*.tlz|*.zip|*.Z)
				output_filename="${input_filename}.aes"
				function CAT() { pv "$@"; }
				;;
			*.jpg|*.jpeg|*.png|*.xlsx|*.docx)
				output_filename="${input_filename}.aes"
				function CAT() { pv "$@"; }
				;;
			*.bfe|*.gpg|*.nc|*.pgp)
				output_filename="${input_filename}.aes"
				function CAT() { pv "$@"; }
				;;
			*)
				output_filename="${input_filename}.xz.aes"
				function CAT() { pv "$@" | xz -C sha256 -c ; }
				;;
		esac
		CAT "$input_filename" | openssl enc $cipher -salt -pass env:secret \
			-out "$output_filename"
		if [[ -s "$output_filename" ]]
		then
			TRASH "$input_filename"
			echo "$output_filename"
		else
			echo Encryption failed on "$input_filename" >&2
			exit -1
		fi
		echo "$output_filename"
	done
}

function encrypt() {
	key_file="aes.key"
	echo "Using $key_file" >&2
	if [[ -s "$key_file" ]]
	then
		secret=$(openssl enc -d $cipher -in "$key_file")
	else
		# use a random string as a session key.
		secret=$(openssl rand 244)
		openssl enc $cipher -salt -out $key_file <<< "$secret"
	fi
	echo "$key_file"
	export secret
	_encrypt_files "$@"
	export secret=
}

function _decrypt_out() {
	[[ "$secret" ]] || { echo "Obtaining key failed"; exit -9; }
	for input_filename
	do
		openssl enc -d $cipher -pass env:secret \
			-in "${input_filename}" \
		| case "$input_filename" in
			*.gz.*)
				gzip -cd
				;;
			*.xz.*)
				xz -cd
				;;
			*)
				cat -n
				;;
		esac
	done
}

function _decrypt_files() {
	[[ "$secret" ]] || { echo "Obtaining key failed"; exit -9; }
	for input_filename
	do
		case "$input_filename" in
			*.aes)
				output_filename="${input_filename%.aes}"
				openssl enc -d $cipher -pass env:secret \
					-in "${input_filename}" \
					-out "$output_filename"
				if [[ -s "$output_filename" ]]
				then
					TRASH "${input_filename}"
					echo "$output_filename"
				else
					echo "Decryption failed on $input_filename" >&2
					exit -1
				fi
				;;
		esac
	done
	for input_filename
	do
		case "$input_filename" in
			*.aes|*.key)
				continue
				;;
			*)
				echo "$input_filename" ignored >&2
				;;
		esac
	done
}

function decrypt() {
	for input_filename
	do
		case "$input_filename" in
			*.key)
				key_file="$input_filename"
				echo "Using $key_file" >&2
				export secret=$(openssl enc -d $cipher -in "$key_file")
				;;
		esac
	done
	_decrypt_files "$@"
	export secret=
}

