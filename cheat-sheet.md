
# OpenSSL command-line cheat sheet
Remember that OpenSSL is a library, and the library has features not exposed to the command line.

## Testing
    cipher=aes-128-ctr
### Baseline:
    openssl speed -elapsed -evp $cipher

### Intel AES-NI instructions disabled:
    OPENSSL_ia32cap="~0x200000200000000" openssl speed -elapsed -evp $cipher

## Symmetric encryption and decryption
### AES with ASCII armor
    enc_cipher='-aes-128-ctr -md SHA256'
    openssl enc -e $enc_cipher -in plaintext -a
    openssl enc -d $enc_cipher -a -in ciphertext

Input files can be omitted for standard in

## Key management
### PKCS8 key wrapping
(password must be 4-1023 characters)

    openssl pkcs8 -topk8 -in openssl_key

### PKCS8 key unwrapping
    openssl pkcs8 -in openssl_key

## Public key cryptosystems
    openssl_req_options='-config openssl.cnf -sha256 -nodes'
    openssl_pkcs8_options='-v2 aes128 -v2prf hmacWithSHA256'
    openssl_signing_options='-pkeyopt digest:SHA256'

### Shared secret derivation
This appears to work for RSA, but not EC

    openssl pkeyutl -derive -inkey your_private_key -peerkey their_public_key -out shared_secret

Remember to protect shared_secret, for example shred before deletion. Exporting a variable with binary contents, like the output of this command, may fail.

### File signing
    openssl dgst -sha256 -sign your_private_key file
    openssl pkeyutl -sign $openssl_signing_options -in file -inkey your_private_key
### Signature verification
    openssl dgst -sha256 -verify their_public_key -signature file.sig file
    openssl pkeyutl -verify -pubin $openssl_signing_options -in file -sigfile file.sig -inkey their_public_key

### RSA
#### Key generation
    openssl req $openssl_req_options -newkey rsa:4096 -out certificate | openssl pkcs8 -topk8 $openssl_pkcs8_options -out private_key

openssl req is designed to output a certificate. Under this usage, no certificate is needed, but I've left the argument in for reference purposes.

    openssl rsa -RSAPublicKey_out -pubout -in private_key > public_key

#### View a key
    openssl rsa -text -in private_key

### Elliptic Curves
    openssl_curve_name=secp521r1
#### list curves
    openssl ecparam -list_curves
#### export a curve

(this might be useful for earlier versions of OpenSSL than yours)

    openssl ecparam -name $openssl_curve_name -param_enc explicit
##### check an exported curve
    openssl ecparam -check -noout
#### View a key
    openssl ec -text -in private_key
#### Key generation

Expects a file called $openssl_curve_name with elliptic curve parameters (see above).

    openssl req $openssl_req_options -newkey ec:$openssl_curve_name -out certificate | openssl pkcs8 -topk8 $openssl_pkcs8_options -out private_key

openssl req is designed to output a certificate. Under this usage, no certificate is needed, but I've left the argument in for reference purposes.

    openssl ec -pubout -in private_key > public_key

## Service Certificates

Edit an openssl-service.cnf for your server.

    openssl_req_options='-config openssl-service.cnf -nodes -days 365'
    openssl req -new -x509 $openssl_req_options -out $CERTFILE -keyout $KEYFILE
    chmod 0600 $KEYFILE
    openssl x509 -subject -fingerprint -noout -in $CERTFILE

## Certificate Authority
    openssl_req_options='-config ca.cnf -utf8 -days 365'
    openssl_key_name='Your name here'
#### CA key generation
Be careful and use a different Common Name from other keys.

    openssl req -x509 $openssl_req_options -newkey rsa:4096 -keyout ca_private_key -out ca_certificate

#### Client
    openssl_key_name='Your name here'
    openssl req -new -key client_private_key -out client.csr

client.csr is disposable

##### Signing
    openssl_x509_options='-config client.cnf -utf8 -days 365 -CA ca_certificate -CAkey ca_private_key'

This is handled by the CA:

    openssl x509 -req $openssl_x509_options -in client.csr -out client_certificate

This is handled by the client:

    openssl pkcs12 -name "$openssl_key_name" -export -in client_certificate -inkey client_private_key -out client.p12
client_private_key is disposable

## S/MIME
    openssl_req_options='-config openssl.cnf -utf8 -days 365'
    openssl_key_name='Your name here'
#### Key generation
    openssl req -x509 $openssl_req_options -newkey rsa:4096 -keyout smime_private_key -out certificate
    openssl pkcs12 -name "$openssl_key_name" -export -in certificate -inkey smime_private_key -out certificate.p12
certificate is disposable
