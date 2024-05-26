#!/bin/bash

if [ -z "$1" ]; then
  echo "Please provide the private instance IP address"
  exit 1
fi

PRIVATE_INSTANCE_IP=$1
KEY_PATH=${KEY_PATH:-~/key.pem}
NEW_KEY_PATH=~/new_key.pem
NEW_KEY_PUB_PATH=~/new_key.pem.pub

# Generate a new SSH key pair
ssh-keygen -t rsa -b 2048 -f $NEW_KEY_PATH -q -N ""

# Extract the new public key
NEW_PUBLIC_KEY=$(cat $NEW_KEY_PUB_PATH)

# Copy the new public key to the private instance
echo "Adding the new public key to the private instance..."
ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_INSTANCE_IP" "echo '$NEW_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
  echo "Failed to add the new public key"
  exit 1
fi

# Verify the new key works
echo "Verifying the new key..."
ssh -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_INSTANCE_IP" "exit"
if [ $? -ne 0 ]; then
  echo "Failed to authenticate with the new key"
  exit 1
fi

# Remove all keys except the new key and the specified key to keep
echo "Removing all old keys except the new key and the specified key to keep..."
ssh -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_INSTANCE_IP" "\
  echo '$NEW_PUBLIC_KEY' > ~/.ssh/authorized_keys"

# Verify the old key no longer works
echo "Verifying the old key no longer works..."
ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_INSTANCE_IP" "exit"
if [ $? -eq 0 ]; then
  echo "Old key still works, failed to remove it"
  exit 1
fi

mv $NEW_KEY_PATH $KEY_PATH
rm $NEW_KEY_PUB_PATH

echo "SSH key rotation completed successfully"
