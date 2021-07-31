# openssl-certificate
We use certificate in some example for SSL conncection for HTTP or gRPC, it will be show how to creating CA and certificates by bash scripts.

# Getting Started

the Script to creating CA and Certificates using OpenSSL.

We use .PEM because of the certificates file(.crt) is PEM format.

## Type(1): Server/Client Certificate with Root CA

Root CA [create-ca.sh](./create-ca.sh)
```
  openssl genrsa -out private/root-ca.key 4096
  
  # Check the new private key is ok (as with any key)
  openssl rsa -in private/root-ca.key -check

  openssl req -new -x509 -days 3650 -key private/root-ca.key -out cert/root-ca.pem -config openssl.cnf -batch

  # Create a template CRL file
  openssl ca -keyfile private/root-ca.key -cert cert/root-ca.pem -gencrl -out crl/crl.pem -config openssl.cnf

  # Test the CRL is ok
  openssl crl -in crl/crl.pem -text
```

using the `openssl.cnf`

Server  [create-cert.sh](./create-cert.sh)
```
  openssl genrsa -out private/server.key 4096

  # Create the server CSR
  openssl req -config openssl.cnf -key private/server.key -new -sha256 -out csr/server.csr

  # Sign the server CSR
  openssl ca -extensions v3_req -notext -md sha256 -in csr/server.csr -out cert/server.pem -config openssl.cnf

  # Create server PFX/P12 file (single password protected file that contains the CA root cert, server key and server cert)
  openssl pkcs12 -export -out cert/server.pfx -inkey private/server.key -in cert/server.pem -certfile ../ca/cert/root-ca.pem -password pass:123456
```


## Type(2): Self-Signed Certficate for Server.


``` bash
openssl genrsa -out server.key 4096
openssl req -new -x509 -days 3650 -key server.key -out server.pem -subj "/C=CN/ST=mykey/L=mykey/O=mykey/OU=mykey/CN=domain1/CN=domain2/CN=domain3"
```


``` bash
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -out server.crt -signkey server.key -days 3650
```

``` bash
openssl req -new -x509 -keyout server.key -out server.crt -config openssl.cnf
```

## Other Useful Commands

Convert DER to CRT 
`openssl x509 -inform DER -in certificate.cer > certificate.crt`

Retrieve CA Certificate 
`openssl x509 -text -noout -in mycertificatefile.crt`


## Github Action
For CI/CD purposing, create sample ca and cert by Github Action, it easier to get certs for other project or other repos dependency.  
[Github Action config](.github/workflows/blank.yml)  
[Examples for the CA and Certs](https://github.com/oslook/openssl-certificate/suites/3377117009/artifacts/79577065)
