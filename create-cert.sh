#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: ./createCSR.sh <certName>"
  exit 1
fi

mkdir $1
cd $1
mkdir cert
mkdir private
mkdir csr
chmod 700 private

export ca=root-ca
cat <<HEREDOC > openssl.cnf
[default]
ca                      = $ca
dir                     = ../ca
base_url                = http://example.com      # CA base URL
aia_url                 = \$base_url/\$ca.cer     # CA certificate URL
crl_url                 = \$base_url/\$ca.crl     # CRL distribution point
name_opt                = multiline,-esc_msb,utf8 # Display UTF-8 characters

[ ca ]
default_ca              = root_ca                 # The default CA section

[ root_ca ]
certificate             = \$dir/cert/\$ca.pem       # The CA cert
private_key             = \$dir/private/\$ca.key    # CA private key
new_certs_dir           = \$dir/\$ca                # Certificate archive
serial                  = \$dir/db/\$ca.serial      # Serial number file
crlnumber               = \$dir/db/\$ca.crlnumber   # CRL number file
database                = \$dir/db/index.txt        # Index file
unique_subject          = no                        # Require unique subject
default_days            = 3652                  # How long to certify for
default_md              = sha1                  # MD to use
policy                  = match_pol             # Default naming policy
email_in_dn             = no                    # Add email to cert DN
preserve                = no                    # Keep passed DN ordering
name_opt                = \$name_opt            # Subject DN display options
cert_opt                = ca_default            # Certificate display options
copy_extensions         = none                  # Copy extensions from CSR
default_crl_days        = 30                    # How long before next CRL
crl_extensions          = crl_ext               # CRL extensions
crl                     = \$dir/crl/crl.pem   	# The current CRL

[match_pol]
countryName            = match
stateOrProvinceName    = optional
organizationName       = match
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
HEREDOC

read -p "Country [CN]>" COUNTRY
export COUNTRY=${COUNTRY:-"CN"}
read -p "State [Beijing]>" STATE
export STATE=${STATE:-"Beijing"}
read -p "City [Beijing]>" CITY
export CITY=${CITY:-"Beijing"}
read -p "Org [Example Ltd]>" ORG
export ORG=${ORG:-"Example Ltd"}
read -p "Division>" DIVISION
export DIVISION=${DIVISION:-"example.com"}
read -p "CN>" CN
export CN=${CN:-"example.com"}

cat <<HEREDOC >> openssl.cnf
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORG
OU = $DIVISION
CN = $CN
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
HEREDOC

read -p "Do you want SANs [Y/N]>" SAN
if [[ $SAN =~ ^[Yy]$ ]]; then
  echo "subjectAltName = @alt_names" >> openssl.cnf
  echo "[alt_names]" >> openssl.cnf

  index=1
  while true; do
    read -p "DNS.$index>" SAN
    if [ -z "$SAN" ]; then
       break;
    fi
    echo "DNS.$index = $SAN" >> csr/$1.san
    index=$((index+1))
  done
  index=1
  while true; do
    read -p "IP.$index>" SAN
    if [ -z "$SAN" ]; then
       cat csr/$1.san >> openssl.cnf
       break;
    fi
    echo "IP.$index = $SAN" >> csr/$1.san
    index=$((index+1))
  done
fi

echo "Here's the settings:"
cat openssl.cnf
read -p "Is this OK [y/n]?" OK

if [[ $OK =~ ^[Yy]$ ]]; then
  # Create the Server Private Key
  openssl genrsa -out private/$1.key 2048
  chmod 400 private/$1.key

  # Create the server CSR
  openssl req -config openssl.cnf -key private/$1.key -new -sha256 -out csr/$1.csr

  # Sign the server CSR
  openssl ca -extensions v3_req -notext -md sha256 -in csr/$1.csr -out cert/$1.pem -config openssl.cnf

  # Create server PFX/P12 file (single password protected file that contains the CA root cert, server key and server cert)
  openssl pkcs12 -export -out cert/$1.pfx -inkey private/$1.key -in cert/$1.pem -certfile ../ca/cert/root-ca.pem -password pass:123456
  # Remove the CSR, key and cert files as desired

  tar czf ../$1.tgz csr/$1.csr csr/$1.san

  echo "Certificate request and certificate is stored into $1.tgz"
else
  echo "Aborting"
fi