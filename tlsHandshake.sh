#!/bin/bash

# Check if server IP is provided
if [ -z "$1" ]; then
  echo "Usage: bash tlsHandshake.sh <server-ip>"
  exit 1
fi

SERVER_IP=$1

# Step 1: Client Hello
CLIENT_HELLO_RESPONSE=$(curl -s -X POST "$SERVER_IP:8080/clienthello" -H "Content-Type: application/json" -d '{
  "version": "1.3",
  "ciphersSuites": [
    "TLS_AES_128_GCM_SHA256",
    "TLS_CHACHA20_POLY1305_SHA256"
  ],
  "message": "Client Hello"
}')

if [ $? -ne 0 ]; then
  echo "Failed to send Client Hello."
  exit 1
fi

echo "Client Hello sent."

# Step 2: Parse Server Hello response
VERSION=$(echo $CLIENT_HELLO_RESPONSE | jq -r '.version')
CIPHER_SUITE=$(echo $CLIENT_HELLO_RESPONSE | jq -r '.cipherSuite')
SESSION_ID=$(echo $CLIENT_HELLO_RESPONSE | jq -r '.sessionID')
SERVER_CERT=$(echo $CLIENT_HELLO_RESPONSE | jq -r '.serverCert')

if [ -z "$VERSION" ] || [ -z "$CIPHER_SUITE" ] || [ -z "$SESSION_ID" ] || [ -z "$SERVER_CERT" ]; then
  echo "Failed to parse Server Hello response."
  exit 1
fi

# Save server certificate to file
echo $SERVER_CERT | base64 -d > cert.pem

echo "Server Hello received. Version: $VERSION, Cipher Suite: $CIPHER_SUITE, Session ID: $SESSION_ID"

# Step 3: Server Certificate Verification
wget -q https://alonitac.github.io/DevOpsTheHardWay/networking_project/cert-ca-aws.pem -O cert-ca-aws.pem
openssl verify -CAfile cert-ca-aws.pem cert.pem

if [ $? -ne 0 ]; then
  echo "Server Certificate is invalid."
  exit 5
fi

echo "Server Certificate verified."

# Step 4: Generate and Encrypt Master Key
MASTER_KEY=$(openssl rand -base64 32)
echo $MASTER_KEY > master-key.txt
ENCRYPTED_MASTER_KEY=$(openssl smime -encrypt -aes-256-cbc -in master-key.txt -outform DER cert.pem | base64 -w 0)

if [ -z "$ENCRYPTED_MASTER_KEY" ]; then
  echo "Failed to encrypt master key."
  exit 1
fi

# Prepare key exchange message
KEY_EXCHANGE_RESPONSE=$(curl -s -X POST "$SERVER_IP:8080/keyexchange" -H "Content-Type: application/json" -d "{
  \"sessionID\": \"$SESSION_ID\",
  \"masterKey\": \"$ENCRYPTED_MASTER_KEY\",
  \"sampleMessage\": \"Hi server, please encrypt me and send to client!\"
}")

if [ $? -ne 0 ]; then
  echo "Failed to exchange master key."
  exit 1
fi

echo "Master key exchanged."

# Step 5: Parse and Decrypt Sample Message
ENCRYPTED_SAMPLE_MESSAGE=$(echo $KEY_EXCHANGE_RESPONSE | jq -r '.encryptedSampleMessage')
DECODED_SAMPLE_MESSAGE=$(echo $ENCRYPTED_SAMPLE_MESSAGE | base64 -d)

if [ -z "$DECODED_SAMPLE_MESSAGE" ]; then
  echo "Failed to decode sample message."
  exit 1
fi

# Decrypt the sample message
DECRYPTED_SAMPLE_MESSAGE=$(echo $DECODED_SAMPLE_MESSAGE | openssl enc -d -aes-256-cbc -pbkdf2 -k $MASTER_KEY)

if [ "$DECRYPTED_SAMPLE_MESSAGE" != "Hi server, please encrypt me and send to client!" ]; then
  echo "Server symmetric encryption using the exchanged master-key has failed."
  exit 6
fi

echo "Client-Server TLS handshake has been completed successfully"
