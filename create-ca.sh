#!/bin/bash

if [ $# -ne 0 ]; then
  echo "Usage: ./createCA.sh"
  exit 1
fi

mkdir ca
cd ca
mkdir -pv {cert,private,db,crl}
chmod 700 private

export ca="root-ca"
mkdir -pv $ca

cat <<HEREDOC > openssl.cnf
[default]
ca                      = $ca
dir                     = .
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

[ crl_ext ]
authorityKeyIdentifier  = keyid:always
authorityInfoAccess     = @issuer_info

[ issuer_info ]
caIssuers;URI.0         = \$aia_url

[ crl_info ]
URI.0                   = \$crl_url

HEREDOC

read -p "Country [CN]>" COUNTRY
export COUNTRY=${COUNTRY:-"CN"}
read -p "Org [Example Ltd]>" ORG
export ORG=${ORG:-"Example Ltd"}
read -p "CN>" CN
export CN=${CN:-"Example Root CA"}

cat <<HEREDOC >> openssl.cnf
[req]
default_bits       = 4096
encrypt_key        = no
default_md         = sha256
utf8               = yes
string_mask        = utf8only
distinguished_name = ca_dn
req_extensions     = ca_ext
x509_extensions		= v3_ca	  # The extensions to add to the self signed cert

[ v3_ca ]
# Extensions for a typical CA
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = CA:true
keyUsage = cRLSign, keyCertSign

[ca_dn]
countryName              = "C"
countryName_default      = $COUNTRY
organizationName         = "O"
organizationName_default = $ORG
commonName               = "CN"
commonName_default       = $CN

[ca_ext]
basicConstraints         = critical,CA:true
keyUsage                 = critical,keyCertSign,cRLSign
subjectKeyIdentifier     = hash
HEREDOC

echo "Here's the settings:"
cat openssl.cnf
read -p "Is this OK [y/n]?" OK

if [[ $OK =~ ^[Yy]$ ]]; then
  echo 1000 >> db/$ca.serial
  echo 1000 >> db/$ca.crlnumber
  touch db/index.txt
  touch db/index.txt.attr

  openssl genrsa -out private/$ca.key 4096
  chmod 400 private/$ca.key

  # Check the new private key is ok (as with any key)
  openssl rsa -in private/$ca.key -check

  openssl req -new -x509 -days 3650 -key private/$ca.key -out cert/$ca.pem -config openssl.cnf -batch

  # Create a template CRL file
  openssl ca -keyfile private/$ca.key -cert cert/$ca.pem -gencrl -out crl/crl.pem -config openssl.cnf

  # Test the CRL is ok
  openssl crl -in crl/crl.pem -text

  tar czf ../$ca.tgz cert/$ca.pem
  echo "Root Certificate is stored into $ca.tgz"
else
  echo "Aborting"
fi