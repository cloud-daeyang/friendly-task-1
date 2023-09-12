#!/bin/bash
aws iam create-user --user-name bastion

aws iam create-policy --policy-name assume-role-policy --policy-document file://assume-role-policy.json

aws iam attach-user-policy --user-name bastion --policy-arn arn:aws:iam::635867519280:policy/assume-role-policy

aws iam create-access-key --user-name bastion

aws iam create-role --role-name assume-role-role --assume-role-policy-document file://assume-role-trust-relationship.json

aws iam create-policy --policy-name aws-eks-admin-policy --policy-document file://aws-eks-admin-policy.json

aws iam attach-role-policy --role-name assume-role-role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws sts assume-role --role-arn arn:aws:iam::635867519280:role/assume-role-role --role-session-name assume-role-session

export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=