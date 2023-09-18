#!/bin/bash
aws iam create-policy --policy-name read-policy --policy-document file://read-role-policy.json
aws iam create-role --role-name read --assume-role-policy-document file://read-role-trust-policy.json
aws iam attach-role-policy --role-name read --policy-arn arn:aws:iam::635867519280:policy/read-role-policy

creds=$(aws sts assume-role --role-arn arn:aws:iam::635867519280:role/read --role-session-name read-session
export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')