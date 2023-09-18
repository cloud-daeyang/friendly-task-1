```
terraform init
terraform plan #optional
terraform apply

eksctl create cluster -f cluster.yml
eksctl utils update-cluster-endpoints --name=wsi-cluster --private-access=true --public-access=false --approve
```