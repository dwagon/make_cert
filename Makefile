# See https://jamielinux.com/docs/openssl-certificate-authority/introduction.html
.PHONY: root_cert intermediate_cert server_cert intermediate_crl root_crl destroy outputs puppet
ROOT_DIR := root-ca
ROOT_CONF := openssl_root.conf

INTERMEDIATE_DIR := intermediate
INTERMEDIATE_CONF := openssl_intermediate.conf

OUTPUT_DIR := output

all: root_cert intermediate_cert outputs

################################################################################
root_cert: ${ROOT_DIR}/certs/ca.cert.pem

${ROOT_DIR}/.created:
	-@ [ ! -d ${ROOT_DIR} ] && mkdir ${ROOT_DIR}
	-@ [ ! -d ${ROOT_DIR}/newcerts ] && mkdir ${ROOT_DIR}/newcerts
	touch ${ROOT_DIR}/index.txt
	echo 1000 > ${ROOT_DIR}/serial
	@ touch ${ROOT_DIR}/.created

${ROOT_DIR}/private/ca.key.pem: ${ROOT_DIR}/.created
	@ echo "Making Root Key"
	-@ [ ! -d ${ROOT_DIR}/private ] && mkdir ${ROOT_DIR}/private
	chmod 0700 ${ROOT_DIR}/private
	openssl genrsa -out ${ROOT_DIR}/private/ca.key.pem 4096
	chmod 0400 ${ROOT_DIR}/private/ca.key.pem

${ROOT_DIR}/certs/ca.cert.pem: ${ROOT_DIR}/private/ca.key.pem
	@ echo "Making Root Cert"
	-@ [ ! -d ${ROOT_DIR}/certs ] && mkdir ${ROOT_DIR}/certs
	openssl req -config ${ROOT_CONF} -new -x509 -days 3650 -key ${ROOT_DIR}/private/ca.key.pem -sha256 -extensions v3_ca -out ${ROOT_DIR}/certs/ca.cert.pem
	chmod 0444 ${ROOT_DIR}/certs/ca.cert.pem
	openssl x509 -noout -text -in ${ROOT_DIR}/certs/ca.cert.pem

################################################################################
root_crl: ${ROOT_DIR}/crl/ca.crl.pem

${ROOT_DIR}/crl/ca.crl.pem: ${ROOT_DIR}/certs/ca.cert.pem
	@ echo "Making CA CRL"
	-@ [ ! -d ${ROOT_DIR}/crl ] && mkdir ${ROOT_DIR}/crl
	echo "1000" > ${ROOT_DIR}/crlnumber
	openssl ca -config ${ROOT_CONF} -gencrl -out ${ROOT_DIR}/crl/ca.crl.pem
	openssl crl -in ${ROOT_DIR}/crl/ca.crl.pem -noout -text

################################################################################
intermediate_cert: ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem

${INTERMEDIATE_DIR}/.created:
	-@ [ ! -d ${INTERMEDIATE_DIR} ] && mkdir ${INTERMEDIATE_DIR}
	-@ [ ! -d ${INTERMEDIATE_DIR}/newcerts ] && mkdir ${INTERMEDIATE_DIR}/newcerts
	touch ${INTERMEDIATE_DIR}/index.txt
	echo "unique_subject = yes" > ${INTERMEDIATE_DIR}/index.txt.attr
	echo 1000 > ${INTERMEDIATE_DIR}/serial
	@ touch ${INTERMEDIATE_DIR}/.created

${INTERMEDIATE_DIR}/private/intermediate.key.pem: ${INTERMEDIATE_DIR}/.created
	@ echo "Making intermediate key"
	-@ [ ! -d ${INTERMEDIATE_DIR}/private ] && mkdir ${INTERMEDIATE_DIR}/private
	openssl genrsa -out ${INTERMEDIATE_DIR}/private/intermediate.key.pem 4096
	chmod 0400 ${INTERMEDIATE_DIR}/private/intermediate.key.pem

${INTERMEDIATE_DIR}/csr/intermediate.csr.pem: ${INTERMEDIATE_DIR}/private/intermediate.key.pem
	@ echo "Making intermediate csr"
	-@ [ ! -d ${INTERMEDIATE_DIR}/csr ] && mkdir ${INTERMEDIATE_DIR}/csr
	openssl req -config ${INTERMEDIATE_CONF} -new -sha256 -key ${INTERMEDIATE_DIR}/private/intermediate.key.pem -out ${INTERMEDIATE_DIR}/csr/intermediate.csr.pem


${INTERMEDIATE_DIR}/certs/intermediate.cert.pem: ${INTERMEDIATE_DIR}/csr/intermediate.csr.pem
	@ echo "Making intermediate cert"
	-@ [ ! -d ${INTERMEDIATE_DIR}/certs ] && mkdir ${INTERMEDIATE_DIR}/certs
	openssl ca -config ${ROOT_CONF} -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in ${INTERMEDIATE_DIR}/csr/intermediate.csr.pem -out ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem
	chmod 0444 ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem
	openssl x509 -noout -text -in ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem
	openssl verify -CAfile ${ROOT_DIR}/certs/ca.cert.pem ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem


################################################################################
intermediate_crl: ${INTERMEDIATE_DIR}/crl/intermediate.crl.pem

${INTERMEDIATE_DIR}/crl/intermediate.crl.pem: ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem
	@ echo "Making CRL"
	-@ [ ! -d ${INTERMEDIATE_DIR}/crl ] && mkdir ${INTERMEDIATE_DIR}/crl
	echo "1000" > ${INTERMEDIATE_DIR}/crlnumber
	openssl ca -config ${INTERMEDIATE_CONF} -gencrl -keyfile ${INTERMEDIATE_DIR}/private/intermediate.key.pem -out ${INTERMEDIATE_DIR}/crl/intermediate.crl.pem
	openssl crl -in ${INTERMEDIATE_DIR}/crl/intermediate.crl.pem -noout -text

################################################################################
server_cert: ${INTERMEDIATE_DIR}/certs/server.cert.pem

${INTERMEDIATE_DIR}/private/server.key.pem:
	@ echo "Making server key"
	openssl genrsa -out ${INTERMEDIATE_DIR}/private/server.key.pem 2048
	chmod 400 ${INTERMEDIATE_DIR}/private/server.key.pem

${INTERMEDIATE_DIR}/csr/server.csr.pem: ${INTERMEDIATE_DIR}/private/server.key.pem
	@ echo "Making server CSR"
	openssl req -config ${INTERMEDIATE_CONF} -key ${INTERMEDIATE_DIR}/private/server.key.pem -new -sha256 -out ${INTERMEDIATE_DIR}/csr/server.csr.pem

${INTERMEDIATE_DIR}/certs/server.cert.pem: ${INTERMEDIATE_DIR}/csr/server.csr.pem ${OUTPUT_DIR}/ca-chain.cert.pem
	@ echo "Making server cert"
	openssl ca -config ${INTERMEDIATE_CONF} -extensions server_cert -days 375 -notext -md sha256 -in ${INTERMEDIATE_DIR}/csr/server.csr.pem -out ${INTERMEDIATE_DIR}/certs/server.cert.pem
	chmod 444 ${INTERMEDIATE_DIR}/certs/server.cert.pem
	openssl x509 -noout -text -in ${INTERMEDIATE_DIR}/certs/server.cert.pem
	openssl verify -CAfile ${OUTPUT_DIR}/ca-chain.cert.pem ${INTERMEDIATE_DIR}/certs/server.cert.pem

################################################################################
outputs: ${OUTPUT_DIR}/crl_chains.pem ${OUTPUT_DIR}/ca-chain.cert.pem

${OUTPUT_DIR}/crl_chains.pem: ${ROOT_DIR}/crl/ca.crl.pem ${INTERMEDIATE_DIR}/crl/intermediate.crl.pem
	@ echo "Making crl chains"
	-@ [ ! -d ${OUTPUT_DIR} ] && mkdir ${OUTPUT_DIR}
	cat ${INTERMEDIATE_DIR}/crl/intermediate.crl.pem ${ROOT_DIR}/crl/ca.crl.pem  > ${OUTPUT_DIR}/crl_chains.pem

${OUTPUT_DIR}/ca-chain.cert.pem: ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem ${ROOT_DIR}/certs/ca.cert.pem
	@ echo "Making cert bundle"
	-@ [ ! -d ${OUTPUT_DIR} ] && mkdir ${OUTPUT_DIR}
	/bin/rm -f ${OUTPUT_DIR}/ca-chain.cert.pem
	cat ${INTERMEDIATE_DIR}/certs/intermediate.cert.pem ${ROOT_DIR}/certs/ca.cert.pem > ${OUTPUT_DIR}/ca-chain.cert.pem
	chmod 444 ${OUTPUT_DIR}/ca-chain.cert.pem

################################################################################
puppet: puppet/.created puppet/bundle.pem puppet/crls.pem puppet/intermediate_key.pem

puppet/.created:
	-@ [ ! -d puppet ] && mkdir puppet
	@ touch puppet/.created

puppet/bundle.pem: ${OUTPUT_DIR}/ca-chain.cert.pem
	cp ${OUTPUT_DIR}/ca-chain.cert.pem puppet/bundle.pem

puppet/crls.pem: ${OUTPUT_DIR}/crl_chains.pem
	cp ${OUTPUT_DIR}/crl_chains.pem puppet/crls.pem

puppet/intermediate_key.pem: ${INTERMEDIATE_DIR}/private/intermediate.key.pem
	cp ${INTERMEDIATE_DIR}/private/intermediate.key.pem puppet/intermediate_key.pem

################################################################################
destroy:
	/bin/rm -rf ${INTERMEDIATE_DIR} ${ROOT_DIR} ${OUTPUT_DIR}

# vim: set noet:
