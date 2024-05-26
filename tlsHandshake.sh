#!/bin/bash

# Function to exit with a message
exit_with_message() {
    echo "$1"
    exit "$2"
}

# Function to send Client Hello
send_client_hello() {
    echo "Sending Client Hello..."
    CLIENT_HELLO_RESPONSE=$(curl -s -X POST "http://$SERVER_IP:8080/clienthello" \
        -H "Content-Type: application/json" \
        -d '{
            "version": "1.3",
            "ciphersSuites": ["TLS_AES_128_GCM_SHA256", "TLS_CHACHA20_POLY1305_SHA256"],
            "message": "Client Hello"
        }')
    if [ $? -ne 0 ]; then
        exit_with_message "Failed to send Client Hello." 1
    fi
}

# Function to parse Server Hello response
parse_server_hello() {
    SESSION_ID=$(echo "$CLIENT_HELLO_RESPONSE" | jq -r '.sessionID')
    SERVER_CERT=$(echo "$CLIENT_HELLO_RESPONSE" | jq -r '.serverCert')
    echo "Received Server Hello. Session ID: $SESSION_ID"
}

# Function to store and verify server certificate
store_and_verify_server_cert() {
    echo "Storing and verifying server certificate..."
    echo "$SERVER_CERT" | base64 -d > server_cert.pem
    if [ $? -ne 0 ]; then
        exit_with_message "Failed to decode server certificate." 1
    fi

    wget -q -O cert_ca_aws.pem https://alonitac.github.io/DevOpsTheHardWay/networking_project/cert-ca-aws.pem
    if [ ! -f cert_ca_aws.pem ]; then
        exit_with_message "Failed to download CA certificate." 2
    fi

    openssl verify -CAfile cert_ca_aws.pem server_cert.pem
    if [ $? -ne 0 ]; then
        exit_with_message "Server Certificate is invalid." 5
    fi
    echo "Server Certificate verified."
}

# Function to generate and encrypt master key
generate_and_encrypt_master_key() {
    echo "Generating and encrypting master key..."
    MASTER_KEY=$(openssl rand -base64 32)
    echo "$MASTER_KEY" > master_key.txt

    ENCRYPTED_MASTER_KEY=$(openssl smime -encrypt -aes-256-cbc -in master_key.txt -outform DER server_cert.pem | base64 -w 0)
    if [ -z "$ENCRYPTED_MASTER_KEY" ]; then
        exit_with_message "Failed to encrypt master key." 1
    fi
}

# Function to exchange keys with the server
exchange_keys_with_server() {
    echo "Exchanging keys with the server..."
    KEY_EXCHANGE_RESPONSE=$(curl -s -X POST "http://$SERVER_IP:8080/keyexchange" \
        -H "Content-Type: application/json" \
        -d "{
            \"sessionID\": \"$SESSION_ID\",
            \"masterKey\": \"$ENCRYPTED_MASTER_KEY\",
            \"sampleMessage\": \"Hi server, please encrypt me and send to client!\"
        }")
    if [ $? -ne 0 ]; then
        exit_with_message "Failed to exchange keys." 1
    fi
}

# Function to decrypt and verify the sample message
decrypt_and_verify_sample_message() {
    ENCRYPTED_SAMPLE_MESSAGE=$(echo "$KEY_EXCHANGE_RESPONSE" | jq -r '.encryptedSampleMessage')
    DECODED_SAMPLE_MESSAGE=$(echo "$ENCRYPTED_SAMPLE_MESSAGE" | base64 -d)
    echo "Decrypting the sample message..."
    DECRYPTED_MESSAGE=$(echo "$DECODED_SAMPLE_MESSAGE" | openssl enc -d -aes-256-cbc -pbkdf2 -k "$MASTER_KEY")

    EXPECTED_MESSAGE="Hi server, please encrypt me and send to client!"
    if [ "$DECRYPTED_MESSAGE" != "$EXPECTED_MESSAGE" ]; then
        exit_with_message "Server symmetric encryption using the exchanged master-key has failed." 6
    fi
    echo "Client-Server TLS handshake has been completed successfully"
}

# Check if server IP is provided
if [ $# -ne 1 ]; then
    exit_with_message "Usage: $0 <server-ip>" 1
fi

SERVER_IP=$1

# Execute the functions in sequence
send_client_hello
parse_server_hello
store_and_verify_server_cert
generate_and_encrypt_master_key
exchange_keys_with_server
decrypt_and_verify_sample_message
