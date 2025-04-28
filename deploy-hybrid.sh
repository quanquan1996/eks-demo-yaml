#!/bin/bash

# 设置错误时退出
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 集群名称和区域
CLUSTER_NAME="mytest"
REGION="us-west-2"

# 检查eksctl是否已安装
if ! command -v eksctl &> /dev/null; then
    echo -e "${YELLOW}安装 eksctl...${NC}"
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

# 检查kubectl是否已安装
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}安装 kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# 检查helm是否已安装
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}安装 helm...${NC}"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
fi

# 更新kubeconfig
echo -e "${YELLOW}更新 kubeconfig 以连接到集群 $CLUSTER_NAME...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# 检查集群连接
echo -e "${YELLOW}验证集群连接...${NC}"
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}错误: 无法连接到EKS集群 $CLUSTER_NAME${NC}"
    exit 1
fi
echo -e "${GREEN}成功连接到集群 $CLUSTER_NAME${NC}"

# 获取集群信息
echo -e "${YELLOW}获取集群信息...${NC}"
eksctl get cluster --name=$CLUSTER_NAME --region=$REGION

# 获取节点组信息
echo -e "${YELLOW}获取节点组信息...${NC}"
eksctl get nodegroup --cluster=$CLUSTER_NAME --region=$REGION

# 启用OIDC提供商（如果尚未启用）
echo -e "${YELLOW}检查OIDC提供商状态...${NC}"
if ! eksctl utils associate-iam-oidc-provider --cluster=$CLUSTER_NAME --region=$REGION --approve 2>/dev/null; then
    echo -e "${GREEN}OIDC提供商已存在${NC}"
fi

# 创建命名空间
echo -e "${YELLOW}步骤 1: 创建命名空间...${NC}"
kubectl apply -f base/namespaces/namespaces.yaml
kubectl apply -f infrastructure/monitoring/namespace.yaml

# 使用eksctl创建AWS Load Balancer Controller的IAM角色
echo -e "${YELLOW}步骤 2: 为AWS Load Balancer Controller创建IAM服务账户...${NC}"
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonEKSLoadBalancerControllerPolicy \
  --override-existing-serviceaccounts \
  --approve \
  --region=$REGION

# 使用Helm安装AWS Load Balancer Controller
echo -e "${YELLOW}步骤 3: 使用Helm安装AWS Load Balancer Controller...${NC}"
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 为Prometheus创建IAM服务账户
echo -e "${YELLOW}步骤 4: 为Prometheus创建IAM服务账户...${NC}"
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=monitoring \
  --name=prometheus \
  --attach-policy-arn=arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
  --approve \
  --region=$REGION

# 使用Helm安装Prometheus
echo -e "${YELLOW}步骤 5: 使用Helm安装Prometheus...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set alertmanager.persistentVolume.enabled=false \
  --set server.persistentVolume.enabled=false \
  --set server.service.type=ClusterIP

# 部署应用
echo -e "${YELLOW}步骤 6: 部署应用到开发环境...${NC}"
kubectl apply -k environments/dev/

# 部署其他应用
echo -e "${YELLOW}步骤 7: 部署App1应用...${NC}"
kubectl apply -f applications/app1/

# 验证部署
echo -e "${YELLOW}步骤 8: 验证部署...${NC}"
echo -e "${GREEN}命名空间:${NC}"
kubectl get namespaces

echo -e "${GREEN}开发环境中的资源:${NC}"
kubectl get all -n dev

echo -e "${GREEN}AWS Load Balancer Controller:${NC}"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo -e "${GREEN}Prometheus监控:${NC}"
kubectl get all -n monitoring

echo -e "${GREEN}Ingress资源:${NC}"
kubectl get ingress -A

# 等待Ingress资源创建ALB
echo -e "${YELLOW}等待Ingress资源创建ALB...${NC}"
kubectl wait --namespace dev \
  --for=condition=ready ingress \
  --selector=kubernetes.io/ingress.class=alb \
  --timeout=180s

# 获取ALB地址
echo -e "${YELLOW}获取ALB地址...${NC}"
ALB_ADDRESS=$(kubectl get ingress -n dev -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

echo -e "${GREEN}部署完成!${NC}"
echo -e "您可以通过以下地址访问应用: ${GREEN}http://$ALB_ADDRESS${NC}"
echo "注意: DNS传播可能需要几分钟时间。"
