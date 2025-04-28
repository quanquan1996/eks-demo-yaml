# EKS YAML 配置管理笔记

## 配置管理最佳实践

### 文件组织结构

EKS YAML文件管理的推荐目录结构：

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

### 版本控制

1. **使用Git管理YAML文件**
   - 所有配置文件应该存储在版本控制系统中
   - 使用分支策略管理不同环境的配置
   - 实施代码审查流程

2. **标签和注释**
   - 为所有资源添加一致的标签（app, environment, version等）
   - 使用注释记录变更历史和目的

### 配置管理工具

1. **Kustomize**
   - 使用基础配置和环境特定的覆盖配置
   - 减少重复代码，提高可维护性

2. **GitOps工具**
   - 使用Flux或ArgoCD实现配置自动同步
   - 确保集群状态与Git仓库一致

3. **Helm Charts**
   - 将复杂应用打包为Helm charts
   - 使用values.yaml管理不同环境的配置

### 敏感信息管理

1. **使用Kubernetes Secrets**
   - 不要在YAML文件中硬编码敏感信息
   - 考虑使用外部密钥管理系统如AWS Secrets Manager

2. **使用SOPS或Sealed Secrets**
   - 加密Git仓库中的敏感信息
   - 只在需要时解密

## 资源更变流程

### 标准操作流程

1. **修改YAML配置文件**
   - 使用文本编辑器或IDE修改相关的YAML文件
   - 更新版本号、镜像标签、环境变量、资源限制等

2. **验证修改**
   ```bash
   # 语法检查
   kubectl --dry-run=client -f updated-deployment.yaml
   
   # 或使用专门的验证工具
   kubeval updated-deployment.yaml
   ```

3. **应用更改**
   ```bash
   # 应用单个文件
   kubectl apply -f updated-deployment.yaml
   
   # 应用整个目录
   kubectl apply -f ./manifests/
   
   # 使用kustomize应用
   kubectl apply -k ./overlays/production/
   ```

4. **验证部署状态**
   ```bash
   # 检查部署状态
   kubectl get deployment my-app -o wide
   
   # 查看滚动更新进度
   kubectl rollout status deployment/my-app
   ```

5. **回滚（如果需要）**
   ```bash
   # 回滚到上一个版本
   kubectl rollout undo deployment/my-app
   
   # 回滚到特定版本
   kubectl rollout undo deployment/my-app --to-revision=2
   ```

### GitOps工作流

如果采用GitOps方法，流程会略有不同：

1. **在Git仓库中修改YAML文件**
2. **创建Pull Request/Merge Request**
3. **代码审查和自动化测试**
4. **合并到主分支**
5. **GitOps工具（如ArgoCD或Flux）自动同步更改到集群**

### 使用Helm管理更复杂的应用

如果使用Helm管理应用：

1. **修改values.yaml文件**
2. **更新Chart版本（如果需要）**
3. **应用更改**
   ```bash
   helm upgrade my-release ./my-chart -f values-prod.yaml
   ```
4. **验证部署**
   ```bash
   helm status my-release
   ```
5. **回滚（如果需要）**
   ```bash
   helm rollback my-release 1
   ```

## 单集群多环境与多集群架构

### 单集群多环境

在单集群多环境模式中：
- 使用命名空间隔离不同环境（dev, staging, prod）
- 使用资源配额限制各环境资源使用
- 使用网络策略控制环境间通信

示例命名空间定义：
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    name: dev
    environment: development
```

### 多集群架构

在多集群架构中：
- 每个环境使用独立的EKS集群
- 使用相同的配置结构，但针对不同集群应用
- 使用kubectl上下文管理多集群

应用配置到特定集群：
```bash
# 应用到开发集群
kubectl apply -k environments/dev/ --context dev-cluster

# 应用到预发布集群
kubectl apply -k environments/staging/ --context staging-cluster

# 应用到生产集群
kubectl apply -k environments/prod/ --context prod-cluster
```

## 最佳实践总结

1. **变更前备份**
   ```bash
   kubectl get deployment my-app -o yaml > my-app-backup.yaml
   ```

2. **增量更改**
   - 一次只更改一个组件，避免大规模同时变更

3. **使用标签和注释**
   - 记录变更原因和版本信息

4. **监控部署后的应用状态**
   ```bash
   kubectl get pods -l app=my-app
   kubectl logs -l app=my-app
   ```

5. **使用命名空间隔离**
   - 在非生产环境先测试变更

6. **记录变更**
   - 在团队文档或变更日志中记录重要更改

7. **定期审查和清理**
   - 移除未使用的配置
   - 更新过时的配置

## 当前仓库使用指南

本仓库 `eks-demo-yaml` 采用单集群多环境模式，使用以下命令应用配置：

```bash
# 应用开发环境配置
kubectl apply -k environments/dev/

# 应用特定应用
kubectl apply -f applications/app1/

# 应用基础设施配置
kubectl apply -f infrastructure/networking/
```

通过这种结构化的配置管理方式，可以更有效地管理EKS集群的YAML配置文件，提高可维护性和可靠性。
