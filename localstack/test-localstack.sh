#!/usr/bin/env bash
export AWS_CONFIG_FILE="$(pwd)/aws-config"
export AWS_SHARED_CREDENTIALS_FILE="$(pwd)/aws-credentials"

echo "Testing LocalStack connectivity..."

# Test health endpoint
echo "1. Health check:"
curl -s https://aws.celestium.life/_localstack/health | jq .

# Test S3
echo -e "\n2. S3 buckets:"
aws s3 ls

# Test SQS
echo -e "\n3. SQS queues:"
aws sqs list-queues

# Test DynamoDB
echo -e "\n4. DynamoDB tables:"
aws dynamodb list-tables
