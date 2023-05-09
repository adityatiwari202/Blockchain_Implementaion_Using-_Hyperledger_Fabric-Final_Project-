#!/bin/bash


echo "Deploying"
CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
VERSION="$4"
TYPE="$5"
: ${CHANNEL_NAME:="registrationchannel"}
: ${DELAY:="5"}
: ${LANGUAGE:="node"}
: ${VERSION:=1.1}
: ${TYPE="basic"}

LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
ORGS="registrar users"
TIMEOUT=15

if [ "$TYPE" = "basic" ]; then
  CC_SRC_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode/"
else
  CC_SRC_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode-advanced/"
fi

echo "Channel name : "$CHANNEL_NAME

# import utils
. scripts/utils.sh

## Install new version of chaincode on peer0 of all 3 orgs making them endorsers
echo "Installing chaincode on peer0.rto.centralized-vehicle.com ..."
installChaincode 0 'rto' $VERSION
echo "Installing chaincode on peer1.rto.centralized-vehicle.com ..."
installChaincode 1 'rto' $VERSION
echo "Installing chaincode on peer0.public.centralized-vehicle.com ..."
installChaincode 0 'public' $VERSION
# echo "Installing chaincode on peer0.upgrad.property-registration-network.com.com ..."
# installChaincode 0 'upgrad' $VERSION

# Instantiate chaincode on the channel using peer0.registrar
echo "Instantiating chaincode on channel using peer0.rto.centralized-vehicle.com ..."
instantiateChaincode 0 'rto' $VERSION

echo
echo "Chaincode installed"
echo



exit 0
