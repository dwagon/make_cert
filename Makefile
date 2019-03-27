ROOT_DIR := root-ca
ROOT_CONF := openssl_root.conf 

INTERMEDIATE_DIR := intermediate
INTERMEDIATE_CONF := openssl_intermediate.conf 


all: root_cert intermediate_cert

################################################################################
root_cert: ${ROOT_DIR}/certs/ca.cert

${ROOT_DIR}:
	-@ [ ! -d ${ROOT_DIR} ] && mkdir ${ROOT_DIR}
	touch ${ROOT_DIR}/index.txt
	echo 1000 > ${ROOT_DIR}/serial

${ROOT_DIR}/private/ca.key: ${ROOT_DIR}
	@ echo "Making Root Key"
	-@ [ ! -d ${ROOT_DIR}/private ] && mkdir ${ROOT_DIR}/private
	chmod 0700 ${ROOT_DIR}/private
	openssl genrsa -out ${ROOT_DIR}/private/ca.key 4096
	chmod 0400 ${ROOT_DIR}/private/ca.key

${ROOT_DIR}/certs/ca.cert: ${ROOT_DIR}/private/ca.key
	@ echo "Making Root Cert"
	-@ [ ! -d ${ROOT_DIR}/certs ] && mkdir ${ROOT_DIR}/certs
	openssl req -config ${ROOT_CONF} -new -x509 -days 3650 -key ${ROOT_DIR}/private/ca.key -sha256 -extensions v3_ca -out ${ROOT_DIR}/certs/ca.cert
	chmod 0444 ${ROOT_DIR}/certs/ca.cert
	openssl x509 -noout -text -in ${ROOT_DIR}/certs/ca.cert


################################################################################
intermediate_cert: ${INTERMEDIATE_DIR}/certs/intermediate.cert

${INTERMEDIATE_DIR}:
	-@ [ ! -d ${INTERMEDIATE_DIR} ] && mkdir ${INTERMEDIATE_DIR}

${INTERMEDIATE_DIR}/private/intermediate.key: ${INTERMEDIATE_DIR}
	@ echo "Making intermediate key"
	-@ [ ! -d ${INTERMEDIATE_DIR}/private ] && mkdir ${INTERMEDIATE_DIR}/private
	openssl genrsa -aes256 -out ${INTERMEDIATE_DIR}/private/intermediate.key 4096
	chmod 0400 ${INTERMEDIATE_DIR}/private/intermediate.key

${INTERMEDIATE_DIR}/csr/intermediate.csr: ${INTERMEDIATE_DIR}/private/intermediate.key
	@ echo "Making intermediate csr"
	-@ [ ! -d ${INTERMEDIATE_DIR}/csr ] && mkdir ${INTERMEDIATE_DIR}/csr
	openssl req -config ${INTERMEDIATE_CONF} -new -sha256 -key ${INTERMEDIATE_DIR}/private/intermediate.key -out ${INTERMEDIATE_DIR}/csr/intermediate.csr


${INTERMEDIATE_DIR}/certs/intermediate.cert: ${INTERMEDIATE_DIR}/csr/intermediate.csr
	@ echo "Making intermediate cert"
	-@ [ ! -d ${INTERMEDIATE_DIR}/certs ] && mkdir ${INTERMEDIATE_DIR}/certs
	openssl ca -config ${ROOT_CONF} -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in ${INTERMEDIATE_DIR}/csr/intermediate.csr -out ${INTERMEDIATE_DIR}/certs/intermediate.cert
	chmod 0444 ${INTERMEDIATE_DIR}/certs/intermediate.cert
	openssl x509 -noout -text -in ${INTERMEDIATE_DIR}/certs/intermediate.cert
	openssl verify -CAfile ${ROOT_DIR}/certs/ca.cert ${INTERMEDIATE_DIR}/certs/intermediate.cert

# vim: set noet:
