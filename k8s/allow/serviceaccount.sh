eksctl create iamserviceaccount \
    --cluster=wsi-cluster \
    --namespace=wsi \
    --name=allow-sa \
    --attach-policy-arn=arn:aws:iam::aws:policy/AdministratorAccess \
    --override-existing-serviceaccounts \
    --approve