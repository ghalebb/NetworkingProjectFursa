#!/bin/bash

if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi


if [ -z "$1" ]; then
  echo "Please provide bastion IP address"
  exit 5
fi


PUBLIC_IP=$1
PRIVATE_IP=$2
COMMAND=$3
MACHINE_PRIVATE_KEY="/home/ubuntu/key.pem"


if ! ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" "test -f $NEW_KEY_PATH_FILE"; then
    echo "No private key file in the public instance"
    exit 1
fi

function connect_to_public_instance() {
    ssh -t -i "$KEY_PATH" ubuntu@"PUBLIC_IP"
}

function connect_to_private_instance() {
    ssh -t -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" "ssh -t -i $MACHINE_PRIVATE_KEY ubuntu@$PRIVATE_IP"
}

function run_command_on_private_instance() {
    ssh -t -i "$KEY_PATH" ubuntu@"$PUBLIC_IP" "ssh -t -i $MACHINE_PRIVATE_KEY ubuntu@$PRIVATE_IP '$COMMAND'"
}


if [ -z "$PRIVATE_IP" ]; then
  connect_to_public_instance
elif [ -z "$COMMAND" ]; then
  connect_to_private_instance
else
  run_command_on_private_instance
fi
