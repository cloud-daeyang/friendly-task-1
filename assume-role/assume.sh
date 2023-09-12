#!/bin/bash
aws iam create-policy --policy-name admin-role-policy --policy-document file://admin-role-policy.json
aws iam create-policy --policy-name read-role-policy --policy-document file://read-role-policy.json

aws iam create-role --role-name admin-role --assume-role-policy-document file://admin-role-trust-relationship.json
aws iam create-role --role-name read-role --assume-role-policy-document file://read-role-trust-relationship.json

aws iam attach-role-policy --role-name admin-role --policy-arn arn:aws:iam::635867519280:policy/admin-role-policy
aws iam attach-role-policy --role-name read-role --policy-arn arn:aws:iam::635867519280:policy/read-role-policy

aws sts assume-role --role-arn arn:aws:iam::635867519280:role/admin-role --role-session-name admin-role-session
aws sts assume-role --role-arn arn:aws:iam::635867519280:role/read-role --role-session-name read-role-session

export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=