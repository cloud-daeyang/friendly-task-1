#!/bin/bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

eksctl create iamserviceaccount \
  --cluster=wsi-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::635867519280:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

kubectl apply \
    --validate=false \
    -f https://github.com/jetstack/cert-manager/releases/download/v1.12.3/cert-manager.yaml

echo "Sleep 30초.. cert-manager 생성중..."

sleep 30

sed -i.bak -e 's|your-cluster-name|wsi-cluster|' ./controller.yaml

kubectl apply -f controller.yaml
kubectl apply -f ingclass.yaml

kubectl get deployment -n kube-system aws-load-balancer-controller