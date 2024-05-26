#!/bin/bash

# Check if server IP is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <server-ip>"
    exit 1
fi

SERVER_IP=$1

# Function to print messages
print_message() {
    echo "$1"
}

# Step 1: Send Client Hello
print_message "Sending Client Hello..."
CLIENT_HELLO_RESPONSE=$(curl -s -X POST "http://$SERVER_IP:8080/clienthello" \
    -H "Content-Type: application/json" \
    -d '{
        "version": "1.3",
        "ciphersSuites": ["TLS_AES_128_GCM_SHA256", "TLS_CHACHA20_POLY1305_SHA256"],
        "message": "Client Hello"
    }')

if [ $? -ne 0 ]; then
    print_message "Failed to send Client Hello."
    exit 1
fi

# Extract session ID and server certificate from the response
SESSION_ID=$(echo "$CLIENT_HELLO_RESPONSE" | jq -r '.sessionID')
SERVER_CERT=$(echo "$CLIENT_HELLO_RESPONSE" | jq -r '.serverCert')

print_message "Received Server Hello. Session ID: $SESSION_ID"

# Step 2: Store and verify server certificate
print_message "Storing and verifying server certificate..."
echo "$SERVER_CERT" > server_cert.pem

# Download CA certificate
wget -q -O cert_ca_aws.pem https://alonitac.github.io/DevOpsTheHardWay/networking_project/cert-ca-aws.pem

if [ ! -f cert_ca_aws.pem ]; then
    print_message "Failed to download CA certificate."
    exit 2
fi

# Verify server certificate
openssl verify -CAfile cert_ca_aws.pem server_cert.pem
if [ $? -ne 0 ]; then
    print_message "Server Certificate is invalid."
    exit 5
fi

print_message "Server Certificate verified."

# Step 3: Generate and encrypt master key
print_message "Generating and encrypting master key..."
MASTER_KEY=$(openssl rand -base64 32)
echo "$MASTER_KEY" > master_key.txt

ENCRYPTED_MASTER_KEY=$(openssl smime -encrypt -aes-256-cbc -in master_key.txt -outform DER server_cert.pem | base64 -w 0)

if [ -z "$ENCRYPTED_MASTER_KEY" ]; then
    print_message "Failed to encrypt master key."
    exit 1
fi

# Step 4: Exchange keys with the server
print_message "Exchanging keys with the server..."
KEY_EXCHANGE_RESPONSE=$(curl -s -X POST "http://$SERVER_IP:8080/keyexchange" \
    -H "Content-Type: application/json" \
    -d "{
        \"sessionID\": \"$SESSION_ID\",
        \"masterKey\": \"$ENCRYPTED_MASTER_KEY\",
        \"sampleMessage\": \"Hi server, please encrypt me and send to client!\"
    }")

if [ $? -ne 0 ]; then
    print_message "Failed to exchange keys."
    exit 1
fi

# Extract and decrypt the sample message
ENCRYPTED_SAMPLE_MESSAGE=$(echo "$KEY_EXCHANGE_RESPONSE" | jq -r '.encryptedSampleMessage')
DECODED_SAMPLE_MESSAGE=$(echo "$ENCRYPTED_SAMPLE_MESSAGE" | base64 -d)

print_message "Decrypting the sample message..."
DECRYPTED_MESSAGE=$(echo "$DECODED_SAMPLE_MESSAGE" | openssl enc -d -aes-256-cbc -pbkdf2 -k "$MASTER_KEY")

# Verify decryption
EXPECTED_MESSAGE="Hi server, please encrypt me and send to client!"
if [ "$DECRYPTED_MESSAGE" != "$EXPECTED_MESSAGE" ]; then
    print_message "Server symmetric encryption using the exchanged master-key has failed."
    exit 6
fi

print_message "Client-Server TLS handshake has been completed successfully"
