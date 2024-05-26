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


connect_to_public_instance() {
  ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP"
}

connect_to_private_instance() {
  ssh -i "$KEY_PATH" -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$PUBLIC_IP" ubuntu@"$PRIVATE_IP"
 #  ssh -i "$KEY_PATH" -J ubuntu@"$PUBLIC_IP" ubuntu@"$PRIVATE_IP"
}

run_command_on_private_instance() {
  ssh -i "$KEY_PATH" -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$PUBLIC_IP" ubuntu@"$PRIVATE_IP" "$COMMAND"
#  ssh -i "$KEY_PATH" -J ubuntu@"$PUBLIC_IP" ubuntu@"$PRIVATE_IP" "$COMMAND"
}

if [ -z "$PRIVATE_IP" ]; then
  connect_to_public_instance
elif [ -z "$COMMAND" ]; then
  connect_to_private_instance
else
  run_command_on_private_instance
fi

