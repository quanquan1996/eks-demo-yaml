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

使用提供的部署脚本可以一键部署所有配置：

```bash
# 确保您已连接到EKS集群
aws eks update-kubeconfig --name your-cluster-name --region your-region

# 运行部署脚本
./deploy-eks-config.sh
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

## 最佳实践

1. 所有配置更改通过Git管理
2. 使用分支策略管理不同环境的配置
3. 通过Pull Request进行代码审查
4. 使用标签和注释记录变更
5. 定期审查和清理未使用的配置

## 先决条件

在部署之前，请确保：

1. 已创建EKS集群
2. 已配置kubectl以连接到您的集群
3. 已创建必要的IAM角色，特别是`AmazonEKSLoadBalancerControllerRole`
4. 已安装AWS CLI并配置了适当的权限
