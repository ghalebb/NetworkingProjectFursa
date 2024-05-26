#!/bin/bash

# Check if the private instance IP is provided
if [ -z "$1" ]; then
  echo "Please provide the private instance IP address"
  exit 1
fi

PRIVATE_INSTANCE_IP=$1
NEW_KEY_NAME=new_key
NEW_KEY_PATH=~/.ssh/$NEW_KEY_NAME

# Generate a new key pair
ssh-keygen -t rsa -b 2048 -f $NEW_KEY_PATH -q -N ""

# Copy the new public key to the private instance
ssh ubuntu@$PRIVATE_INSTANCE_IP "mkdir -p ~/.ssh && echo $(cat ${NEW_KEY_PATH}.pub) > ~/.ssh/authorized_keys"

# Test the new key connection
ssh -i $NEW_KEY_PATH ubuntu@$PRIVATE_INSTANCE_IP "echo 'New key works!'"

# Inform the user to update their key paths
echo "Key rotation complete. Update your scripts to use the new key at $NEW_KEY_PATH"
