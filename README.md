
- VEHICLE TRACKING SYSTEM

    It is a basic Hyperledger Fabric Network consisting of two organisations namely RTO and Public having 5 nodes amongst them (excluding the orderer node and the MSP's for both the organisations). Its main job is to track the ownership of vehicles and transfering the ownership of these vehicles if the owner intends to do so.

    Necesary requirements to run the project:

    - Docker
    - Javascript
    - Docker-Compose
    - Node Javascript
    - Bash
    - Python 2.7
    - Golang
    - Curl 

    Steps to run the network:

    - Create a folder "fabric" to make is as the base to install complete hyperledger fabric on your system.
    - Inside this folder open terminal
    - Run the following two commands:

        `git config --global core.autocrlf false`

        `git config --global core.longpaths true`
        
    - Run `sudo chmod 777 /var/run/docker.sock` to grant access to docker.
    - Run  `curl -sSL http://bit.ly/2ysbOFE | bash -s 1.4.4` to install all of the Fabric Docker images in your Local (This step may take sometime)
    - Unzip the Project folder and copy it inside the Fabric Folder.
    - Go to `vehicle-tracking/network` and open the terminal.
    - Generate all the certificates of all the peers using command `./fabricNetwork.sh generate` from their respective MSP's.
    - Bring up docker containers for all the peers of the network using the command `./fabricNetwork.sh up`. This script all brings up the single channel which exists among all the peers of the 	  network.
    - In a new terminal at same directory, install the Node js in the chaincode docker container using commands `docker exec -it chaincode /bin/bash` and  `npm run start-dev`
    - Install the respective chaincodes in the peers of both the organisations using the command `./fabricNetwork.sh install`
    - Open new terminals for Public and RTO respective to make them as a RPC medium to run the commands for transaction
    - In RTO terminal run the following command to make it as a RPC medium `docker exec -it cli /bin/bash`
    - In Public Public run the following commands to make it as a medium for RPC 
        `docker exec -it cli /bin/bash` 

        `export CORE_PEER_LOCALMSPID=publicNode`

        `export CORE_PEER_ADDRESS=peer0.public.centralized-vehicle.com:9051`

        `export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/public.centralized-vehicle.com/users/Admin@public.centralized-vehicle.com/msp`

    - Both the terminals are now ready to make the transactions using their respective chaincode
    - From the public terminal, following transactions can be executed:

        enrollRequest(name,phone,id)

        searchUser(name,id)

        searchCar(Car_id)

        enrollCar(car_id,price,status,name,id)

        updateCarStatus(carid,status,name,id)

        buyCar(carid,name,id)

        fillWallet(name,id,amount)

    - From the RTO terminal, following transactions can be invoked:

        searchUser(name,id)

        approveUser(name,id)

        searchCar(car_id)

        approveCar(car_id)

    - All the above methods provide the output in the terminal itself in form of JSON object as frontend is yet to be implemented.










