#!/bin/bash

# 设置错误时退出
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查kubectl是否已安装
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误: kubectl 未安装，请先安装 kubectl${NC}"
    exit 1
fi

# 检查是否有活动的EKS集群连接
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}错误: 无法连接到EKS集群，请确保您已配置kubectl以连接到您的EKS集群${NC}"
    echo "提示: 使用 'aws eks update-kubeconfig --name your-cluster-name --region your-region' 配置kubectl"
    exit 1
fi

# 获取AWS账户ID
echo -e "${YELLOW}获取AWS账户ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}错误: 无法获取AWS账户ID，请检查AWS CLI配置${NC}"
    exit 1
fi
echo -e "${GREEN}AWS账户ID: $AWS_ACCOUNT_ID${NC}"

# 获取集群名称
echo -e "${YELLOW}获取当前集群名称...${NC}"
CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2)
echo -e "${GREEN}当前集群名称: $CLUSTER_NAME${NC}"

# 更新AWS Load Balancer Controller配置中的账户ID
echo -e "${YELLOW}更新AWS Load Balancer Controller配置...${NC}"
sed -i "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" infrastructure/networking/aws-load-balancer-controller.yaml
sed -i "s/eks-demo-cluster/$CLUSTER_NAME/g" infrastructure/networking/aws-load-balancer-controller.yaml

# 1. 创建命名空间
echo -e "${YELLOW}步骤 1: 创建命名空间...${NC}"
kubectl apply -f base/namespaces/namespaces.yaml
kubectl apply -f infrastructure/monitoring/namespace.yaml

# 2. 部署基础设施组件
echo -e "${YELLOW}步骤 2: 部署AWS Load Balancer Controller...${NC}"
# 检查IAM角色是否存在
if ! aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole 2>/dev/null; then
    echo -e "${YELLOW}创建AWS Load Balancer Controller所需的IAM角色...${NC}"
    # 这里应该有创建IAM角色的代码，但为了安全起见，我们提示用户手动创建
    echo -e "${RED}请先创建名为 'AmazonEKSLoadBalancerControllerRole' 的IAM角色，并附加适当的策略${NC}"
    echo "参考文档: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html"
    exit 1
fi

# 部署AWS Load Balancer Controller
kubectl apply -f infrastructure/networking/aws-load-balancer-controller.yaml

# 3. 部署监控组件
echo -e "${YELLOW}步骤 3: 部署Prometheus监控组件...${NC}"
kubectl apply -f infrastructure/monitoring/prometheus-serviceaccount.yaml
kubectl apply -f infrastructure/monitoring/prometheus-configmap.yaml
kubectl apply -f infrastructure/monitoring/prometheus-deployment.yaml
kubectl apply -f infrastructure/monitoring/prometheus-service.yaml

# 4. 部署应用
echo -e "${YELLOW}步骤 4: 部署应用到开发环境...${NC}"
kubectl apply -k environments/dev/

# 5. 部署其他应用
echo -e "${YELLOW}步骤 5: 部署App1应用...${NC}"
kubectl apply -f applications/app1/

# 6. 验证部署
echo -e "${YELLOW}步骤 6: 验证部署...${NC}"
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

echo -e "${GREEN}部署完成!${NC}"
echo "注意: AWS Load Balancer Controller可能需要几分钟来创建ALB。"
echo "您可以使用以下命令检查ALB的创建状态:"
echo "kubectl get ingress -n dev -w"
