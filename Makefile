root-ca:
	mkdir root-ca

root: root-ca root-ca/certs/ca.cert

root-ca/private/ca.key: root-ca
	@ [ ! -d root-ca/private ] && mkdir root-ca/private
	openssl genrsa -out root-ca/private/ca.key 4096
	chmod 0400 root-ca/private/ca.key

root-ca/certs/ca.cert: root-ca/private/ca.key
	@ [ ! -d root-ca/certs ] && mkdir root-ca/certs
	openssl req -config openssl.conf -new -x509 -days 3650 -key root-ca/private/ca.key -sha256 -extensions v3_ca -out root-ca/certs/ca.cert
	chmod 0444 root-ca/certs/ca.cert
	openssl x509 -noout -text -in root-ca/certs/ca.cert

# vim: set noet:
