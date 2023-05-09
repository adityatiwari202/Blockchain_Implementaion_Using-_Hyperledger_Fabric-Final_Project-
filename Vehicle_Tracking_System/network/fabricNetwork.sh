#!/bin/bash

export PATH=${PWD}/bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
export VERBOSE=false

# Print the usage message






function clearContainers() {
  CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*.mycc.*/) {print $1}')
  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    echo "---- No containers available for deletion ----"
  else
    docker rm -f "$CONTAINER_IDS"
  fi
}


function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*.mycc.*/) {print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f "$DOCKER_IMAGE_IDS"
  fi
}

# Versions of fabric known not to work with this release of first-network
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\.0-preview ^1\.1\.0-alpha"


function checkPrereqs() {
  
  LOCAL_VERSION=$(configtxlator version | sed -ne 's/ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:"$IMAGETAG" peer version | sed -ne 's/ Version: //p' | head -1)

  echo "LOCAL_VERSION=$LOCAL_VERSION"
  echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  

  for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS; do
    echo "$LOCAL_VERSION" | grep -q "$UNSUPPORTED_VERSION"
    if [ $? -eq 0 ]; then
      echo "ERROR! Local Fabric binary version of $LOCAL_VERSION does not match this newer version of registration-network and is unsupported. Either move to a later version of Fabric or checkout an earlier version of registration-network."
      exit 1
    fi

    echo "$DOCKER_IMAGE_VERSION" | grep -q "$UNSUPPORTED_VERSION"
    if [ $? -eq 0 ]; then
      echo "ERROR! Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match this newer version of registration-network and is unsupported. Either move to a later version of Fabric or checkout an earlier version of registration-network."
      exit 1
    fi
  done
}


function networkUp() {
  checkPrereqs
  # generate artifacts if they don't exist
  if [ ! -d "crypto-config" ]; then
    generateCerts
    replacePrivateKey
    generateChannelArtifacts
  fi
  
  IMAGE_TAG=$IMAGETAG docker-compose -f "$COMPOSE_FILE" up -d 2>&1
  
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    exit 1
  fi
  # Wait for 10 seconds to allow the docker network to stabilise
  sleep 1
  sleep 9

  # now run the bootstrap script
  docker exec cli scripts/bootstrap.sh "$CHANNEL_NAME" "$CLI_DELAY" "$LANGUAGE" "$CLI_TIMEOUT" "$VERBOSE"
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Test failed"
    exit 1
  fi
}

# Generate the needed certificates, the genesis block and start the network.
function bootstrapRetry() {
  checkPrereqs
  # now run the bootstrap script
  docker exec cli scripts/bootstrap.sh "$CHANNEL_NAME" "$CLI_DELAY" "$LANGUAGE" "$CLI_TIMEOUT" "$VERBOSE"
}

#function updateChaincode() {
  #checkPrereqs
  #docker exec cli scripts/updateChaincode.sh "$CHANNEL_NAME" "$CLI_DELAY" "$LANGUAGE" "$VERSION_NO" "$TYPE"
#}

function installChaincode() {
  checkPrereqs
  docker exec cli scripts/installChaincode.sh "$CHANNEL_NAME" "$CLI_DELAY" "$LANGUAGE" "$VERSION_NO" "$TYPE"
}

# Tear down running network
function networkDown() {
  
  docker-compose -f "$COMPOSE_FILE" down --volumes --remove-orphans

  # Don't remove the generated artifacts -- note, the ledgers are always removed
  if [ "$MODE" != "restart" ]; then
    # Bring down the network, deleting the volumes
    # Delete any ledger backups
    docker run -v "$PWD":/tmp/registrationchannel --rm hyperledger/fabric-tools:"$IMAGETAG" rm -Rf /tmp/registrationchannel/ledgers-backup
    #Cleanup the chaincode containers
    clearContainers
    #Cleanup images
    removeUnwantedImages
    # remove orderer block and other channel configuration transactions and certs
    rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config
  fi
}


#UPDATE required
function replacePrivateKey() {
  
  ARCH=$(uname -s | grep Darwin)
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi

  # Copy the template to the file that will be modified to add the private key
  cp docker-compose-template.yaml docker-compose-e2e.yml

  # The next steps will replace the template's contents with the
  # actual values of the private key file names for the two CAs.
  CURRENT_DIR=$PWD
  cd crypto-config/peerOrganizations/rto.centralized-vehicle.com/ca/ || exit
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR" || exit
  sed $OPTS "s/REGISTRAR_CA_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yml
  cd crypto-config/peerOrganizations/public.centralized-vehicle.com/ca/ || exit
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR" || exit
  sed $OPTS "s/USERS_CA_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yml
  
  
  if [ "$ARCH" == "Darwin" ]; then
    rm docker-compose-e2e.yml
  fi
}

# Generates Org certs using cryptogen tool
function generateCerts() {
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  

  if [ -d "crypto-config" ]; then
    rm -Rf crypto-config
  fi
  set -x
  cryptogen generate --config=./crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates..."
    exit 1
  fi
  echo
}



#UPDATE required
function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  
  
  set -x
  configtxgen -profile OrdererGenesis -channelID upgrad-sys-channel -outputBlock ./channel-artifacts/genesis.block
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo
  
  set -x
  configtxgen -profile RegistrationChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID "$CHANNEL_NAME"
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi

  echo
  
  set -x
  configtxgen -profile RegistrationChannel -outputAnchorPeersUpdate ./channel-artifacts/rtoNodeanchors.tx -channelID "$CHANNEL_NAME" -asOrg rtoNode
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for registrar..."
    exit 1
  fi

  echo
  
  set -x
  configtxgen -profile RegistrationChannel -outputAnchorPeersUpdate ./channel-artifacts/publicNodeanchors.tx -channelID "$CHANNEL_NAME" -asOrg publicNode
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for users..."
    exit 1
  fi
  echo

  

}

# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=15
# default for delay between commands
CLI_DELAY=5
# channel name defaults to "registrationchannel"
CHANNEL_NAME="registrationchannel"
# version for updating chaincode
VERSION_NO=1.15
# type of chaincode to be installed
TYPE="basic"
# use this as the default docker-compose yaml definition
COMPOSE_FILE=docker-compose-e2e.yml
# use node as the default language for chaincode
LANGUAGE="node"
# default image tag
IMAGETAG="latest"
# Parse commandline args
if [ "$1" = "-m" ]; then # supports old usage, muscle memory is powerful!
  shift
fi
MODE=$1
shift
# Determine which command to run
if [ "$MODE" == "up" ]; then
  EXPMODE="Starting"
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping"
elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting"
elif [ "$MODE" == "retry" ]; then
  EXPMODE="Retrying network bootstrap"
elif [ "$MODE" == "update" ]; then
  EXPMODE="Installing chaincode"
elif [ "$MODE" == "install" ]; then
  EXPMODE="Installing chaincode"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and genesis block"
else
  printHelp
  exit 1
fi

while getopts "h?c:t:d:f:l:i:v:m:" opt; do
  case "$opt" in
  h | \?)
    printHelp
    exit 0
    ;;
  c)
    CHANNEL_NAME=$OPTARG
    ;;
  t)
    CLI_TIMEOUT=$OPTARG
    ;;
  d)
    CLI_DELAY=$OPTARG
    ;;
  f)
    COMPOSE_FILE=$OPTARG
    ;;
  l)
    LANGUAGE=$OPTARG
    ;;
  v)
    VERSION_NO=$OPTARG
    ;;
  m)
    TYPE=$OPTARG
    ;;
  i)
    IMAGETAG=$(go env GOARCH)"-"$OPTARG
    ;;
  esac
done


echo "${EXPMODE} for channel '${CHANNEL_NAME}' with CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and chaincode version '${VERSION_NO}' "



#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateCerts
  replacePrivateKey
  generateChannelArtifacts
elif [ "${MODE}" == "restart" ]; then ## Restart the network
  networkDown
  networkUp
elif [ "${MODE}" == "retry" ]; then ## Retry bootstrapping the network
  bootstrapRetry
elif [ "${MODE}" == "update" ]; then ## Run the composer setup commands
  installChaincode
elif [ "${MODE}" == "install" ]; then ## Run the composer setup commands
  installChaincode
else
  printHelp
  exit 1
fi
