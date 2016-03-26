#!/usr/bin/env bash
set -e

my_private_key=.smime.key
my_public_key=cert.pem

[[ -s "$my_private_key" ]] || echo Running without private key


function smime_gen() {
	[[ "$1" ]] && private_key="$1" || private_key="$my_private_key"
	shift
	[[ -s "$private_key" ]] && { echo Refusing to overwrite "$private_key"; exit -2; }
	openssl req -newkey rsa:2048 -nodes -sha256 -days 365 \
		-keyout "$my_private_key" \
		-out "$my_public_key" -x509
	#echo Signing certificate:
	#openssl x509 -req -signkey "$my_private_key" \
		#-in tmp.pem \
		#-out "$my_public_key" \
	#&& rm tmp.pem
}

function smime_getpub() {
	[[ -s "$1" ]] && private_key="$1" || private_key="$my_private_key"
	[[ -s "$private_key" ]] || { echo Cannot find "$private_key"; exit -2; }
	[[ -s "$my_public_key" ]] && mv -f "$my_public_key" "$my_public_key"~
	echo Generating new public key in "$my_public_key"
	openssl rsa -pubout \
		-in "$private_key" \
		-out "$my_public_key" -pubout
}

function smime_sign() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	for input_filename
	do
		output_filename="${input_filename}.smime"
		openssl smime -sign -text \
			-signer "$my_public_key" \
			-inkey  "$my_private_key" \
			-in "$input_filename" \
			-out "$output_filename"
	done
}

function smime_verify() {
	their_cert="$1"
	shift
	for input_filename
	do
		echo "$input_filename":
		openssl smime -verify -text -in "$input_filename"
	done
}

function smime_extract() {
	input_filename="$1"
	shift
	output_filename="$1"
	shift
	[[ -s "$input_filename" ]] || { echo $input_filename not found; exit -2; }
	[[ -s "$output_filename" ]] && { echo refusing to overwrite $output_filename; exit -2; }
	openssl smime -pk7out \
		-in "$input_filename" \
		-out "$output_filename"
}

function smime_gethash() {
	input_filename="$1"
	openssl x509 -noout -hash -in "$input_filename"
}

function smime_hashlinks() {
	for input_filename
	do
		pref=$(smime_gethash "$input_filename")
		for dest in ${pref}.{0..9}
		do
			echo ln -s "$input_filename" "$dest"
		done
	done
}

function smime_encrypt() {
	their_cert="$1"
	shift
	for input_filename
	do
		output_filename="${input_filename}.smime"
		openssl smime -encrypt -aes256 \
			-in "$input_filename" \
			-binary -out "$output_filename" \
			"$their_cert"
	done
}

function smime_decrypt() {
	[[ -s "$my_private_key" ]] || { echo Cannot find "$my_private_key"; exit -2; }
	for input_filename
	do
		openssl smime -decrypt -in "$input_filename" \
			-recip "$my_public_key" \
			-inkey "$my_private_key"
	done
}


case "$1" in
	cert_links) shift
		smime_hashlinks "$@"
		;;
	d|decrypt) shift
		smime_decrypt "$@"
		;;
	enc|encrypt) shift
		their_cert="$1"
		shift
		smime_encrypt "$their_cert" "$@"
		;;
	ex|extract) shift
		for input_filename
		do
			output_filename="${input_filename}.cert"
			smime_extract "$input_filename" "$output_filename"
		done
	gen|generate) shift
		smime_gen "$@"
		;;
	sig|sign) shift
		smime_sign "$@"
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
	*)
		echo "Invalid command: $@"
		exit -2
		;;
esac
