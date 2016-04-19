#! /usr/bin/env head
### Source this file into your script

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

function encrypt() {
	key_file="aes.key"
	if [[ -s "$key_file" ]]
	then
		echo "Using $key_file" >&2
		secret=$(openssl enc -d -aes256 -in "$key_file")
	else
		# use a random string as a session key.
		export secret=$(openssl rand 244)
		openssl enc -aes256 -salt -out $key_file <<< "$secret"
	fi
	[[ "$secret" ]] || { echo "Obtaining key failed"; exit -9; }
	for input_filename
	do
		case "$input_filename" in
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
	export secret=
}


function decrypt() {
	for input_filename
	do
		case "$input_filename" in
			*.key)
				key_file="$input_filename"
				echo "Using $key_file" >&2
				export secret=$(openssl enc -d -aes256 -in "$key_file")
				;;
		esac
	done
	[[ "$secret" ]] || { echo "Obtaining key failed"; exit -9; }
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

