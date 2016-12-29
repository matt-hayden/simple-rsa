
# OpenSSL command-line cheat sheet
Remember that OpenSSL is a library, and the library has features not exposed to the command line.

## Testing
    ```sh
    cipher=aes-128-ctr
    cipher=aes-128-gcm # your implementation may not support this mode
    ```

### Baseline:
    ```sh
    openssl speed -elapsed -evp $cipher
    ```

### Intel AES-NI instructions disabled:
    ```sh
    OPENSSL_ia32cap="~0x200000200000000" openssl speed -elapsed -evp $cipher
    ```

## Symmetric encryption and decryption
### AES with ASCII armor
    ```sh
    enc_cipher='-aes-128-ctr -md SHA256'
    enc_cipher='-blowfish -md SHA256' # alternatively
    openssl enc -e $enc_cipher -in plaintext -a
    openssl enc -d $enc_cipher -a -in ciphertext
    ```

Input files can be omitted for standard in

## Key management
### Generate CSR

From an existing key:

    openssl req -config openssl.cnf -new -key private/key

From an existing (trusted) certificate:

    openssl req -text -noout -verify -in certificate.pem
    openssl x509 -x509toreq -in certificate.pem -signkey private/key

### PKCS8 key wrapping
(password must be 4-1023 characters)

    ```sh
    openssl_pkcs8_options='-v2 aes128 -v2prf hmacWithSHA256'
    openssl pkcs8 -topk8 $openssl_pkcs8_options -in private/key
    ```

### PKCS8 key unwrapping
    openssl pkcs8 -in private/key

## Public key cryptosystems
    ```sh
    openssl_req_options='-config openssl.cnf -sha256 -nodes'
    echo $openssl_pkcs8_options
    openssl_signing_options='-pkeyopt digest:SHA256'
    ```

### Shared secret derivation
This appears to work for RSA, but not EC

    openssl pkeyutl -derive -inkey your/private/key -peerkey their/public/key -out shared_secret

Remember to protect shared_secret. Exporting a variable with binary contents, like the output of this command, may fail.

### File signing
    ```sh
    openssl dgst -sha256 -sign your/private/key file
    openssl pkeyutl -sign $openssl_signing_options -in file -inkey your/private/key
    ```
### Signature verification
    ```sh
    openssl dgst -sha256 -verify their/public/key -signature file.sig file
    openssl pkeyutl -verify -pubin $openssl_signing_options -in file -sigfile file.sig -inkey their/public/key
    ```

### RSA
#### Key generation
    ```sh
    openssl req -x509 $openssl_req_options -newkey rsa:4096 -out certificate.pem | ...
    ```

Wrap this using PKCS8 for local use.

    ```sh
    openssl rsa -RSAPublicKey_out -pubout -in private/key > public_key
    ```

#### View a key
    openssl rsa -text -in private/key

### Elliptic Curves
    ```sh
    openssl_curve_name=secp521r1
    ```
#### list curves
    openssl ecparam -list_curves
#### export a curve

(this might be useful for earlier versions of OpenSSL than yours)

    ```sh
    openssl ecparam -name $openssl_curve_name -param_enc explicit
    ```

##### check an exported curve
    openssl ecparam -check -noout
#### View a key
    openssl ec -text -in private/key
#### Key generation

Expects a file called $openssl_curve_name with elliptic curve parameters (see above).


    ```sh
    openssl req -x509 $openssl_req_options -newkey ec:$openssl_curve_name -out certificate.pem | ...
    ```

Wrap this using PKCS8 for local use.


    ```sh
    openssl ec -pubout -in private/key > public_key
    ```

## Service Certificates

Edit an openssl-service.cnf for your server into ``$SERVICE.cnf``.

    ```sh
    openssl_req_options='-config $SERVICE.cnf -nodes -days 365'
    ```

Self-signed:

    ```sh
    openssl req -new -x509 $openssl_req_options -out certificate.pem -keyout private/$SERVICE.key
    openssl x509 -fingerprint -sha256 -noout -in certificate.pem
    ```

## Certificate Authority

    ```sh
    openssl_ca_options='-config CA/openssl.cnf -selfsign -extensions v3_ca_has_san -create_serial -days 365'
    openssl_req_options='-config CA/openssl.cnf -utf8 -extensions v3_ca -days 365'
    openssl_key_name='Your name here'
    ```

#### CA key generation

    ```sh
    mkdir CA/{certsdb,certreqs,crl,newcerts,private}
    touch -a CA/index.txt
    ```

Be careful and use a different Common Name and Subject for each key.

    ```sh
    openssl req -x509 $openssl_req_options -newkey rsa:4096 -keyout CA/private/cakey.pem -out CA/careq.pem
    openssl ca $openssl_ca_options -keyfile CA/private/cakey.pem -infiles CA/careq.pem -out CA/cacert.pem
    ```

#### Client

    ```sh
    openssl_key_name='Your name here'
    openssl req -new -key private/client_key -out client.csr
    ```

##### Signing

    ```sh
    openssl_x509_options='-config client.cnf -utf8 -days 365 -CA CA/cacert.pem -CAkey CA/private/cakey.pem'
    ```

This is handled by the CA:

    ```sh
    openssl x509 -req $openssl_x509_options -in client.csr -out client_certificate.pem
    ```

client.csr is disposable

This is handled by the client:


    ```sh
    openssl pkcs12 -name "$openssl_key_name" -export -in client_certificate.pem -inkey private/client_key -out client.p12
    ```

private/client_key is disposable

## S/MIME

    ```sh
    openssl_req_options='-config smime.cnf -utf8 -days 365 -nodes -sha256'
    ```

#### Key generation

    ```sh
    openssl req -x509 $openssl_req_options -newkey rsa:4096 -keyout smime_private/key -out certificate.pem
    openssl pkcs12 -export -aes128 -name "Application displays this" -in certificate.pem -inkey smime_private/key -out smime.p12
    ```

#### Signing
    openssl smime -sign -text -signer certificate.pem -inkey smime_private/key

## Testing
### HTTPS

Test a server's signed certificate:

    ```sh
    CAfile=/usr/share/ca-certificates/mozilla/DigiCert_Assured_ID_Root_CA.crt
    openssl s_client -connect localhost:443 -CAfile $CAfile < /dev/null | openssl x509 -noout -fingerprint -sha256
### IMAP and POP3
    openssl s_client -crlf -connect localhost:110
    ```

### SMTPS

    openssl s_client -starttls smtp -crlf -connect localhost:25

## Google Cloud keys

#### download and extract public key
With the certificate google-cloud-csek-ingress.pem

    ```sh
    openssl x509 -pubkey -noout -in google-cloud-csek-ingress.pem > pubkey.pem
    ```

#### generate 256-bit key and wrap with PKCS#1 OAEP

    ```sh
    openssl rand 32 > private_key
    openssl rsautl -oaep -encrypt -in private_key -pubin -inkey pubkey.pem | openssl base64 -e
    ```

## Linux cryptsetup keys

### master key

    openssl genrsa -aes256 -out privkey.pem 2048

#### generate 256-bit key and wrap with PKCS#1

    ```sh
    openssl rand 32 | openssl rsautl -encrypt -pubin -inkey privkey.pem -out crypt.key
    ```

#### unwrap key

    ```sh
    openssl rsautl -decrypt -in crypt.key -inkey privkey.pem | hexdump -e '"" 32/1 "%02x" "\n"'
    ```

#### change password

Push the old key through ``openssl rsa``.

    ```sh
    mv privkey.pem{,~}
    openssl rsa -in privkey.pem~ -out privkey.pem
    # enter old and new passwords
    shred privkey.pem~
    ```

#### change master key

Repeat for each volume key (``crypt.key`` here).

    ```sh
    mv privkey.pem{,~}
    openssl genrsa -aes256 -out privkey.pem 2048
    # enter new password
    mv crypt.key{,~}
    openssl rsautl -decrypt -in crypt.key~ -inkey privkey.pem~ | openssl rsautl -encrypt -out crypt.key
    # enter old and new passwords
    shred privkey.pem~ crypt.key~
    ```
