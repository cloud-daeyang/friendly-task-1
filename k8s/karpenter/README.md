# 개요
기존에 이미 생성되어 있는 EKS 클러스터에 Karpenter를 설치하는 가이드입니다.

이 가이드에서는 다음과 같이 기존에 존재하던 EKS 클러스터 환경을 가정하고 있습니다.
- 기존 EKS 클러스터를 사용합니다.
- 기존 VPC와 서브넷을 사용합니다.
- 기존 보안 그룹을 사용합니다.
- EC2 노드가 하나 이상의 노드 그룹에 속합니다.
- 클러스터에 Service Account용 OIDC Provider가 이미 있는 상태입니다.

# 배경지식
### Karpenter
Karpenter는 예약할 수 없는 파드를 감지하고 새 노드를 자동으로 프로비저닝하는 오픈 소스 클러스터 오토스케일러입니다.

#### 기능과 동작방식
Karpenter는 리소스 부족으로 인해 Pending 상태인 파드의 총 리소스 요구 사항을 분석한 후 이를 실행할 최적의 EC2 인스턴스 유형을 선택합니다.
데몬셋이 아닌 파드가 없는 인스턴스를 자동으로 축소하거나 종료하여 컴퓨팅 리소스 낭비를 줄입니다.
또한 Pod를 적극적으로 이동하고 노드를 삭제하거나 더 저렴한 인스턴스 타입으로 교체하여 클러스터 비용을 줄이는 노드 통합 기능Consolidation도 지원합니다.

![image](https://github.com/cloud-daeyang/friendly-task-1/assets/86287920/69441e60-7449-4196-ab09-06550421d77d)

- 파드의 리소스 CPU, Memory 요구 사항에 따라 노드를 프로비저닝합니다.
- Provisioner의 다양한 옵션을 사용하여 인스턴스 유형별로 다양한 노드 구성을 생성합니다. Karpenter를 사용하면 여러 EKS 노드 그룹을 관리하는 대신 쿠버네티스 내부에 있는 Provisioner 리소스(CRD)만으로도 다양한 워크로드 용량을 쉽게 관리할 수 있습니다.
- Karpenter는 Cluster Autoscaler 보다 신속하게 노드를 시작하고 Pod를 빠르게 예약하며, 요청된 리소스 크기에 맞게 적절한 인스턴스 타입의 노드를 배치하므로 전체적인 클러스터 컴퓨팅 비용이 더 절약됩니다.

![image](https://github.com/cloud-daeyang/friendly-task-1/assets/86287920/81fb5b98-3530-47e6-82f8-6bf42f95b725)

- **빠른 프로비저닝 속도** : CA는 ASG를 사용하여 노드 수를 조절합니다. 반면에 Karpenter는 EC2 API를 호출해 직접 생성하므로 노드 프로비저닝 속도가 Cluster Autoscaler 보다 빠릅니다. 늘려야할 노드 수가 클 수록 속도차는 점점 벌어집니다.

![image](https://github.com/cloud-daeyang/friendly-task-1/assets/86287920/7d43e9ab-20fa-4ed3-a5c2-6a0f5782c16c)

**General Availability**

Karpenter는 2021년 11월 27일에 v0.5 버전을 출시했습니다.
Karpenter v0.5 이상부터는 정식 버전GA, General Availability이기 때문에 프로덕션 레벨에서도 안심하고 사용 가능합니다.

[AWS 뉴스 - AWS Karpenter v0.5, 이제 정식 버전 제공]

[AWS 뉴스 - AWS Karpenter v0.5, 이제 정식 버전 제공]: https://aws.amazon.com/ko/about-aws/whats-new/2021/11/aws-karpenter-v0-5/

### Provisioner
Karpenter 컨트롤러는 Provisioner라고 하는 리소스(CRD)를 사용합니다. Provisioner는 클러스터에 노드를 동적으로 프로비저닝하는 역할을 수행합니다. Provisioner는 클러스터에 추가 노드가 필요할 때 Karpenter에게 요청을 보내고, Karpenter는 요청에 따라 클러스터에 노드를 자동으로 추가합니다. Provisioner는 이러한 작업을 수행하기 위해 클라우드 제공 업체 API 또는 기타 클러스터 프로비저닝 도구와 통합됩니다.

요약하자면 Karpenter에서 Provisioner는 클러스터 자원을 동적으로 관리하여 애플리케이션의 요구에 따라 적절한 수의 노드를 프로비저닝하는 역할을 하는 리소스입니다.

### IRSA
IRSA <sup>IAM Role for Service Account</sup>는 Kubernetes의 ServiceAccount 리소스를 사용하여 Pod의 권한을 IAM Role로 제어할 수 있도록 하는 권한 기능을 말합니다.

![image](https://github.com/cloud-daeyang/friendly-task-1/assets/86287920/65c8e58f-49cd-40cd-a90e-df518d6de31d)

위 그림은 Pod 내부에서 동작하는 Application이 ```s3:ListBuckets``` 권한을 얻은 다음 AWS S3 Buket의 목록을 가져오는 경우, IRSA 동작 흐름 예시입니다.

[Diving into IAM Roles for Service Accounts]

[Diving into IAM Roles for Service Accounts]: https://aws.amazon.com/ko/blogs/containers/diving-into-iam-roles-for-service-accounts/

Karpenter Controller와 Karpenter가 생성한 노드의 경우 다음과 같이 IRSA가 구성됩니다.

![image](https://github.com/cloud-daeyang/friendly-task-1/assets/86287920/ca4a9b6f-b1af-41e7-b8f4-57e97ee3323e)

# Karpenter 설치
### 초기 환경변수 설정
EKS 클러스터 이름에 대한 환경변수를 설정합니다.
```
CLUSTER_NAME=YOUR_CLUSTER_NAME_HERE
```

다른 환경변수도 설정합니다.
아래 환경변수 4개는 Karpenter 설치 과정에서 사용됩니다.
```
AWS_PARTITION="aws"
AWS_REGION="$(aws configure list | grep region | tr -s " " | cut -d" " -f3)"
OIDC_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text)"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
```

### IAM Role 생성

**Karpenter** 노드용 **IAM Role**

Karpenter 노드용 IAM Role을 생성하기 위해 Role의 신뢰 관계를 생성합니다.
```
echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}' > node-trust-policy.json
```

Karpenter로 생성한 노드에서 사용할 IAM Role을 생성합니다. IAM Role의 신뢰 관계는 이전에 만든 node-trust-policy.json의 내용을 그대로 적용합니다.
```
aws iam create-role \
    --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
    --assume-role-policy-document file://node-trust-policy.json
```

KarpenterNodeRole에 EKS 노드에게 필수적으로 필요한 권한 4개를 붙입니다.
```
aws iam attach-role-policy \
    --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
    --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy \
    --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy \
    --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

Karpenter가 배포한 EC2에서 해당 롤을 사용할 수 있도록 EC2 Instance Profile을 생성합니다.
```
aws iam create-instance-profile \
    --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}"

aws iam add-role-to-instance-profile \
    --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}" \
    --role-name "KarpenterNodeRole-${CLUSTER_NAME}"
```

**Karpenter** 컨트롤러용 **IAM Role**

이제 Karpenter 컨트롤러가 새 인스턴스를 프로비저닝하는 데 사용할 IAM 역할을 생성해야 합니다.

Karpenter 컨트롤러는 IRSAIAM Role for Service Accout 방식으로 IAM 권한을 얻어 EC2 생성, 삭제를 수행합니다.

IAM Role의 신뢰 관계를 생성합니다.
```
cat << EOF > controller-trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_ENDPOINT#*//}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${OIDC_ENDPOINT#*//}:aud": "sts.amazonaws.com",
                    "${OIDC_ENDPOINT#*//}:sub": "system:serviceaccount:karpenter:karpenter"
                }
            }
        }
    ]
}
EOF
```

Karpenter 컨트롤러에서 사용할 IAM Role을 생성합니다.
```
aws iam create-role \
    --role-name KarpenterControllerRole-${CLUSTER_NAME} \
    --assume-role-policy-document file://controller-trust-policy.json
```

Karpenter 컨트롤러용 IAM Policy를 생성합니다.
```
cat << EOF > controller-policy.json
{
    "Statement": [
        {
            "Action": [
                "ssm:GetParameter",
                "ec2:DescribeImages",
                "ec2:RunInstances",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeAvailabilityZones",
                "ec2:DeleteLaunchTemplate",
                "ec2:CreateTags",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateFleet",
                "ec2:DescribeSpotPriceHistory",
                "pricing:GetProducts"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "Karpenter"
        },
        {
            "Action": "ec2:TerminateInstances",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/Name": "*karpenter*"
                }
            },
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "ConditionalEC2Termination"
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}",
            "Sid": "PassNodeIAMRole"
        },
        {
            "Effect": "Allow",
            "Action": "eks:DescribeCluster",
            "Resource": "arn:${AWS_PARTITION}:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}",
            "Sid": "EKSClusterEndpointLookup"
        }
    ],
    "Version": "2012-10-17"
}
EOF
```

인라인 정책<sup>Inline Policy</sup>를 Karpenter Controller용 IAM Role에 연결합니다.
```
aws iam put-role-policy \
    --role-name KarpenterControllerRole-${CLUSTER_NAME} \
    --policy-name KarpenterControllerPolicy-${CLUSTER_NAME} \
    --policy-document file://controller-policy.json
```

### 서브넷 및 보안 그룹에 태그 추가
Karpenter 컨트롤러가 EC2 노드를 추가 생성 시, 사용할 서브넷을 알 수 있도록 노드 그룹 서브넷에 karpenter.sh/discovery 태그를 추가합니다.

![image](https://github.com/cloud-daeyang/friendly-task-1/assets/86287920/34ac4d29-aa9d-4b7d-9480-6d95821411cc)

**Subnet**

EKS 클러스터의 서브넷에 태그를 추가하는 AWS CLI 명령어입니다.
for 반복문 형태로 여러 서브넷에 한 번에 태그가 추가됩니다.
```
for NODEGROUP in $(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
    --query 'nodegroups' --output text); do aws ec2 create-tags \
        --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
        --resources $(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
        --nodegroup-name $NODEGROUP --query 'nodegroup.subnets' --output text )
done
```

추가되는 태그 정보는 다음과 같습니다.
- **Key** : karpenter.sh/discovery
- **Value** : 현재 사용중인 자신의 EKS 클러스터 이름을 찾아 자동 입력됨

**Security Group**

보안 그룹에 태그를 추가합니다.
이 명령은 클러스터의 첫 번째 노드 그룹에 대한 보안 그룹에만 karpenter.sh/discovery 태그를 지정합니다.
노드 그룹 또는 보안 그룹이 여러 개인 경우 Karpenter가 사용해야 하는 그룹을 결정해야 합니다.
```
$ NODEGROUP=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
    --query 'nodegroups[0]' --output text)

$ LAUNCH_TEMPLATE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
    --nodegroup-name ${NODEGROUP} --query 'nodegroup.launchTemplate.{id:id,version:version}' \
    --output text | tr -s "\t" ",")

# EKS 설정이 클러스터 보안 그룹만 사용하도록 구성된 경우 실행 -

$ SECURITY_GROUPS=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

# Manage Node Group의 시작 템플릿에 있는 Security Group을 사용하는 경우 -

$ SECURITY_GROUPS=$(aws ec2 describe-launch-template-versions \
    --launch-template-id ${LAUNCH_TEMPLATE%,*} --versions ${LAUNCH_TEMPLATE#*,} \
    --query 'LaunchTemplateVersions[0].LaunchTemplateData.[NetworkInterfaces[0].Groups||SecurityGroupIds]' \
    --output text)

$ aws ec2 create-tags \
    --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
    --resources ${SECURITY_GROUPS}
```

### aws-auth ConfigMap 업데이트
방금 생성한 노드 IAM 역할을 사용하는 EC2 노드가 EKS 클러스터에 가입하도록 허용해줍니다.

관련 설정은 aws-auth ConfigMap에서 관리됩니다.
```
kubectl edit configmap aws-auth -n kube-system
```

변경 전 aws-auth ConfigMap 내용입니다.
```
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::111122223333:role/xxxxxxxxxx
      username: system:node:{{EC2PrivateDNSName}} 
+   - groups:
+     - system:bootstrappers
+     - system:nodes
+     rolearn: arn:aws:iam::111122223333:role/KarpenterNodeRole-YOUR_CLUSTER_NAME_HERE
+     username: system:node:{{EC2PrivateDNSName}}   
kind: ConfigMap
metadata:
  ...
```
변경 후에는 위와 같이 두 개의 그룹이 있어야 합니다. 하나는 Karpenter 노드 Role용이고 다른 하나는 기존 노드 그룹용입니다.

### Karpenter 배포
이 가이드에서는 helm 차트를 사용해서 클러스터에 Karpenter v0.25.0를 배포합니다.

작업자의 로컬 환경에 helm CLI v3.12.3 이상이 설치되어 있어야 합니다.
```
helm version --short
v3.12.3+g293b50c
```

[Karpenter 릴리즈 노트]를 참고하여 배포하려는 Karpenter 버전을 설정합니다.

[Karpenter 릴리즈 노트]: https://github.com/aws/karpenter/releases
```
export KARPENTER_VERSION=v0.30.0
```

이제 helm 차트에서 전체 Karpenter 배포 yaml을 생성할 수 있습니다.
```
helm template karpenter oci://public.ecr.aws/karpenter/karpenter \
    --version ${KARPENTER_VERSION} \
    --namespace karpenter \
    --set settings.aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-${CLUSTER_NAME} \
    --set settings.aws.clusterName=${CLUSTER_NAME} \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${CLUSTER_NAME}" \
    --set controller.resources.requests.cpu=1 \
    --set controller.resources.requests.memory=1Gi \
    --set controller.resources.limits.cpu=1 \
    --set controller.resources.limits.memory=1Gi \
    --set replicas=2 > karpenter.yaml
```

### Karpenter Controller Pod의 배치 설정

- Karpenter Controller 파드들은 Karpenter가 스스로 생성한 워커노드에 배치되면 안됩니다. 운 나쁘게 자기 자신이 위치한 EC2 노드를 스스로 Terminate 하게 될 경우, 클러스터 전체의 노드 프로비저닝이 멈출 수 있기 때문입니다. 이러한 이유로 Karpenter Controller Pod는 기존 Auto Scaling Group 기반에서 운영되는 노드그룹에 배치되어야 합니다.

- 위와 같은 이유로 클러스터에 Karpenter를 설치해서 사용하더라도 최소 1개의 노드그룹은 반드시 필요합니다. 저도 처음엔 “Karpenter를 쓰면 노드그룹(ASG)은 하나도 필요 없겠네?“라고 생각했지만 현재로서는 불가능합니다. 처음 Karpenter를 쓸 때 쉽게 혼동할 수 있는 부분입니다.

- 적절한 파드 분배 (선택사항): Karpenter 공식문서에서는 클러스터 운영 및 유지에 필요한 핵심 파드들은 nodeAffinity를 사용해 기존 ASG로 운영되는 노드그룹에 배치하는 걸 권장하고 있습니다. 파드 배치의 예시는 다음과 같습니다.

    - 기존 노드그룹<sup>ASG</sup>에 배치
        - karpenter
        - coredns
        - metrics-server
        - prometheus
        - grafana
    - **Karpenter** 노드에 배치
        - Backend Application Pod
        - Frontend Application Pod
        - Data Application Pod

vi 에디터를 사용해서 방금 헬름으로 생성한 karpenter.yaml 파일을 수정합니다.
```
vi karpenter.yaml
```

karpenter.yaml 파일에서 Karpenter의 nodeAffinity 설정 부분을 찾습니다.
```
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: karpenter.sh/provisioner-name
                operator: DoesNotExist
+           - matchExpressions:
+             - key: eks.amazonaws.com/nodegroup
+               operator: In
+               values:
+               - YOUR_NODE_GROUP_NAME  # 노드그룹 이름은 현재 사용중인 노드 그룹으로 수정하기
```

Karpenter Pod가 기존 노드그룹 중 하나에서 실행되도록 nodeAffinity 설정을 수정합니다.

```nodeAffinity``` 설정에 의해 Karpenter Controller 파드들은 기존에 사용하던 ASG 기반의 워커노드 그룹에 배포됩니다.

이제 Karpenter 배포가 준비되었습니다.

```karpenter``` 네임스페이스를 새로 만듭니다.
```
kubectl create namespace karpenter
```

Karpenter가 새 노드를 프로비저닝할 때 사용하는 CRD인 provisioners와 awsnodetemplates을 생성합니다.
```
kubectl create -f https://raw.githubusercontent.com/aws/karpenter/$KARPENTER_VERSION/pkg/apis/crds/karpenter.sh_provisioners.yaml


kubectl create -f https://raw.githubusercontent.com/aws/karpenter/$KARPENTER_VERSION/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml
```

생성 후에는 ```kubectl api-resources``` 명령어로 CRD 목록을 확인합니다.
```
kubectl api-resources \
    --categories karpenter \
    -o wide
```

```awsnodetemplates```과 ```provisioners``` 리소스가 새로 추가된 걸 확인할 수 있습니다.

```
NAME               SHORTNAMES   APIVERSION                   NAMESPACED   KIND              VERBS                                                        CATEGORIES
awsnodetemplates                karpenter.k8s.aws/v1alpha1   false        AWSNodeTemplate   delete,deletecollection,get,list,patch,create,update,watch   karpenter
provisioners                    karpenter.sh/v1alpha5        false        Provisioner       delete,deletecollection,get,list,patch,create,update,watch   karpenter
```

```karpenter.yaml``` 파일을 사용해서 Karpenter를 클러스터에 배포합니다.
```
kubectl apply -f karpenter.yaml
```

Karpenter Controller 파드는 고가용성을 위해 기본적으로 2개 배포됩니다.
```
kubectl get pod -n karpenter
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-558b968fb7-5bq48   1/1     Running   0          9m20s
karpenter-558b968fb7-6g9lw   1/1     Running   0          18m
```
위와 같이 모두 Running 상태면 Karpenter 배포가 완료된 것입니다.

### Provisioner 생성
Karpenter가 예약되지 않은 워크로드에 대해 원하는 노드 유형을 알 수 있도록 Default Provisioner를 생성해야 합니다.
```
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["on-demand"]
    - key: "node.kubernetes.io/instance-type"
      operator: In
      values: ["c", "t", "m"]
    - key: "topology.kubernetes.io/zone"
      operator: In
      values: ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  limits:
    resources:
      cpu: 1000
  providerRef:
    name: default
  consolidation:
    enabled: true
---
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  subnetSelector:
    karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelector:
    karpenter.sh/discovery: "${CLUSTER_NAME}"
```
위 Provisioner 설정을 해석하면 다음과 같습니다.
- karpenter.k8s.aws/instance-category : 카펜터가 노드 타입 선택시 ```c, t, m``` 패밀리만 사용합니다.
- karpenter.k8s.aws/instance-generation : 카펜터가 노드 타입 선택시 3세대 이상 사용합니다. ```c5, m2, t3``` …

Provisioner의 설정 방법은 Karpenter 공식문서의 spec.requirements를 참고하세요.