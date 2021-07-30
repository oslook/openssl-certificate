#!/bin/bash

# CA
function ca() {
  rm -rf ca
  ./create-ca.sh <<EOF
CN
Example Ltd
Example Root CA
y
EOF
}

# gen
function gen() {
  rm -rf $1
  ./create-cert.sh $1 <<EOF
CN
Beijing
Beijing
Example Ltd
Development
$1.example.com
y
ns1.example.com

0.0.0.0

y
y
y
EOF

}

ca
gen "server"
gen "client1"
gen "client2"
gen "client3"
gen "client4"