#!/usr/bin/env bash
set -e

my_private_key=.rsa_private.key
my_public_key=public.pem

[[ -s "$my_private_key" ]] || my_private_key=$HOME/"$my_private_key"
[[ -s "$my_private_key" ]] || echo Running without private key

function pkgen() {
	[[ -s "$1" ]] && private_key="$1" || private_key="$my_private_key"
	shift
	[[ -s "$private_key" ]] && { echo Refusing to overwrite "$private_key"; exit -2; }
	openssl genrsa -aes256 -out "$private_key" 2048
}

function pkgetpub() {
	[[ -s "$1" ]] && private_key="$1" || private_key="$my_private_key"
	[[ -s "$private_key" ]] || { echo Cannot find "$private_key"; exit -2; }
	[[ -s "$my_public_key" ]] && mv -f "$my_public_key" "$my_public_key"~
	echo Generating new public key in "$my_public_key"
	openssl rsa -in $private_key -out $my_public_key -outform PEM -pubout
}

function pkencrypt() {
	their_public_key="$1"
	shift
	for input_filename
	do
		# 244-245 bytes seems to be the largest size of an RSA encrypt
		size=$(stat -c%s "$input_filename")
		if [[ $size -le 244 ]]
		then # small enough to ecrypt with public-key
			output_filename="${input_filename}.rsa"
			openssl rsautl -encrypt -inkey $their_public_key -pubin \
				-in "$input_filename" \
				-out "$output_filename"
		else # too big for public-key
			output_filename="${input_filename}.aes"
			key_filename="${input_filename}.rsa"
			export otpass=$(openssl rand 244)
			gzip -c "${input_filename}" | \
			openssl enc -aes-256-cbc -salt -pass env:otpass \
				-out "$output_filename"
			openssl rsautl -encrypt -inkey $their_public_key -pubin \
				-out "$key_filename" <<< "$otpass"
			otpass=
		fi
	done
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
		sig_filename="${input_filename}.sig"
		echo "${input_filename}":
		openssl dgst -sha256 -verify $their_public_key \
			-signature "$sig_filename" \
			"$input_filename"
	done
}

function pkdecrypt() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	for input_filename
	do
		case "$input_filename" in
			*.rsa)
				openssl rsautl -decrypt -inkey "$my_private_key" \
					-in "$input_filename"
				;;
			*.aes)
				key_filename="${input_filename%.*}.rsa"
				[[ -s "$key_filename" ]] || { echo Expected "$key_filename"; exit -3; }
				export otpass=$(openssl rsautl -decrypt -inkey "$my_private_key" \
					-in "$key_filename")
				openssl enc -d -aes-256-cbc -pass env:otpass \
					-in "${input_filename}" | \
				gzip -dc
				otpass=
				;;
			*)
				echo File "$input_filename" not understood
				exit -3
				;;
		esac
	done
}

function pkpasswd() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	openssl rsa -in "$my_private_key" -aes256 -out tmp.key
	shred "$my_private_key" && mv tmp.key "$my_private_key" || echo Error prevented changing password of "$my_private_key"
}

case "$1" in
	d|decrypt) shift
		pkdecrypt "$@"
		;;
	enc|encrypt) shift
		pkencrypt "$@"
		;;
	gen|generate) shift
		pkgen
		[[ -s "$my_public_key" ]] && pkgetpub
		;;
	sig|sign) shift
		pksign "$@"
		[[ -s "$my_public_key" ]] && pkgetpub
		;;
	v|verify) shift
		pkverify "$@"
		;;
	info) shift
		echo private:
		if [[ -e "$my_private_key" ]]
		then
			ls -l "$my_private_key"
		else
			echo None
		fi
		;;
	mksum) shift
		pkmksum "$@"
		[[ -s "$my_public_key" ]] && pkgetpub
		;;
	chksum) shift
		pkchksum "$@"
		;;
	*)
		echo "Invalid command: $@"
		exit -2
		;;
esac
