# EKS Demo YAML

这个仓库用于管理AWS EKS集群的Kubernetes配置文件。

## 目录结构

```
eks-demo-yaml/
├── base/                  # 基础配置
│   ├── namespaces/        # 命名空间定义
│   ├── deployments/       # 基础部署配置
│   ├── services/          # 基础服务配置
│   └── configmaps/        # 基础配置映射
├── environments/          # 环境特定配置
│   ├── dev/               # 开发环境
│   ├── staging/           # 预发布环境
│   └── prod/              # 生产环境
├── applications/          # 按应用分组
│   ├── app1/              # 应用1配置
│   └── app2/              # 应用2配置
└── infrastructure/        # 基础设施配置
    ├── storage/           # 存储相关配置
    ├── networking/        # 网络相关配置
    └── monitoring/        # 监控相关配置
```

## 快速部署

提供了多种部署脚本选项，可以根据需要选择：

### 1. 混合部署方式（推荐）

结合使用 eksctl、Helm 和 kubectl 的优势：

```bash
# 运行混合部署脚本
./deploy-hybrid.sh
```

这个脚本会：
- 使用 eksctl 管理集群基础设施和IAM角色
- 使用 Helm 部署复杂组件（如AWS Load Balancer Controller和Prometheus）
- 使用 kubectl 部署应用资源

### 2. 仅使用 kubectl 部署

```bash
# 确保您已连接到EKS集群
aws eks update-kubeconfig --name your-cluster-name --region your-region

# 运行kubectl部署脚本
./deploy-eks-config.sh
```

### 3. 使用 eksctl 管理集群配置

```bash
# 应用或更新集群配置
eksctl apply -f cluster-config.yaml
```

## 部署的资源

应用此配置将部署以下资源：

1. **命名空间**:
   - `dev`, `staging`, `prod`, `monitoring`

2. **应用服务**:
   - Nginx部署 (1个副本)
   - App1部署 (2个副本)
   - 相关服务和ConfigMap

3. **基础设施组件**:
   - AWS Load Balancer Controller
   - Prometheus监控系统

4. **网络资源**:
   - 基于ALB的Ingress资源

## 手动部署方法

### 应用配置

```bash
# 应用基础配置
kubectl apply -f base/namespaces/

# 应用开发环境配置
kubectl apply -f environments/dev/

# 应用特定应用配置
kubectl apply -f applications/app1/
```

### 使用Kustomize

```bash
# 应用开发环境的完整配置
kubectl apply -k environments/dev/
```

## 使用 eksctl 管理集群

### 查看集群状态
```bash
eksctl get cluster --name=mytest --region=us-west-2
```

### 管理节点组
```bash
# 查看节点组
eksctl get nodegroup --cluster=mytest --region=us-west-2

# 扩展节点组
eksctl scale nodegroup --cluster=mytest --name=managed-ng --nodes=3 --region=us-west-2
```

### 管理附加组件
```bash
# 列出可用附加组件
eksctl utils describe-addon-versions --cluster=mytest --region=us-west-2

# 安装或更新附加组件
eksctl create addon --name vpc-cni --cluster=mytest --region=us-west-2
```

## 最佳实践

1. 所有配置更改通过Git管理
2. 使用分支策略管理不同环境的配置
3. 通过Pull Request进行代码审查
4. 使用标签和注释记录变更
5. 定期审查和清理未使用的配置
6. 使用eksctl管理AWS特定资源，kubectl管理Kubernetes资源

## 先决条件

在部署之前，请确保：

1. 已创建EKS集群
2. 已安装必要的工具：
   - AWS CLI
   - kubectl
   - eksctl
   - Helm (用于混合部署)
3. 已配置AWS凭证，具有适当的权限
