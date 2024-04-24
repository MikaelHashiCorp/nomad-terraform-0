#!/bin/bash

# Releases: https://releases.hashicorp.com/
# Binary Directory:  whereis ${PRODUCT}
PRODUCT=consul 
VERSION=1.13.9
OS=linux_amd64
BINARY_DIRECTORY="/usr/bin"
TOTAL_DURATION=20
INTERVAL=10

echo "${PRODUCT} ${VERSION} ${OS} ${BINARY_DIRECTORY}"

# PRODUCT=nomad ; VERSION=1.3.16+ent ; OS=linux_amd64 && echo "${PRODUCT} ${VERSION} ${OS}"

PRODUCTDOWNLOAD=https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_${OS}.zip 
echo "PRODUCTDOWNLOAD: curl ${PRODUCTDOWNLOAD} -o ${PRODUCT}_${VERSION}.zip"

curl ${PRODUCTDOWNLOAD} -o ${PRODUCT}_${VERSION}.zip && ls -al

unzip -o ${PRODUCT}_${VERSION}.zip
ls -al
./${PRODUCT} version

sudo systemctl stop ${PRODUCT}
sudo systemctl status ${PRODUCT} | cat

sudo rm ${BINARY_DIRECTORY}/${PRODUCT}
sudo ls -al ${BINARY_DIRECTORY}/${PRODUCT}
sudo mv ${PRODUCT} ${BINARY_DIRECTORY} 
sudo ls -al ${BINARY_DIRECTORY}/${PRODUCT}
sudo chown root:root ${BINARY_DIRECTORY}/${PRODUCT} 
sudo ls -al ${BINARY_DIRECTORY}/${PRODUCT}
${PRODUCT} version

sudo rm -rf /opt/${PRODUCT}/data
sudo ls -al /opt/${PRODUCT}

sudo systemctl restart ${PRODUCT}
sudo systemctl status ${PRODUCT} | cat
for ((i=TOTAL_DURATION/INTERVAL; i>0; i--))
  do
    echo -e "\n*** $((i*INTERVAL)) seconds until JOURNALCTL stops scrolling. ***\n"
    sudo timeout $INTERVAL journalctl -fu ${PRODUCT}
  done
echo
${PRODUCT} version