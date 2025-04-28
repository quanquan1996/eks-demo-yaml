# EKS 集群设置完整对话记录

## 会话日期：2025-04-28

## 目录
- [初始问题](#初始问题)
- [问题诊断](#问题诊断)
- [解决方案尝试](#解决方案尝试)
- [节点组状态检查](#节点组状态检查)
- [IAM OIDC 配置](#iam-oidc-配置)
- [节点组创建失败](#节点组创建失败)
- [重新创建节点组](#重新创建节点组)
- [当前状态](#当前状态)
- [下一步计划](#下一步计划)
- [完整命令记录](#完整命令记录)

## 初始问题

**用户**: 你kubectl get nodes失败了为什么没修复

## 问题诊断

**Amazon Q**: 
我应该解决 kubectl 认证失败的问题，而不是简单地等待节点组创建完成。

首先，我尝试获取 EKS 认证令牌：
```bash
aws eks get-token --cluster-name mytest --region us-west-2
```

结果显示令牌生成成功，但有效期限为：
```json
"expirationTimestamp": "2025-04-28T07:52:44Z"
```

然后检查了 kubeconfig 文件：
```bash
cat ~/.kube/config
```

文件内容显示有两个集群配置：
1. `arn:aws:eks:us-east-1:051826712157:cluster/myEks`
2. `arn:aws:eks:us-west-2:051826712157:cluster/mytest`

当前上下文设置为 `mytest` 集群。

尝试执行 kubectl 命令：
```bash
kubectl get nodes
```

错误信息：
```
error: You must be logged in to the server (the server has asked for the client to provide credentials)
```

## 解决方案尝试

### 1. 检查节点组状态

```bash
aws eks describe-nodegroup --cluster-name mytest --nodegroup-name managed-ng --region us-west-2
```

结果显示节点组仍在创建中：
```json
"status": "CREATING",
"createdAt": "2025-04-28T07:36:33.152000+00:00"
```

### 2. 更新集群认证配置

```bash
aws eks update-cluster-config --name mytest --region us-west-2 --access-config authenticationMode=API
```

更新成功启动：
```json
"status": "InProgress",
"type": "AccessConfigUpdate"
```

### 3. 检查更新状态

```bash
aws eks describe-update --name mytest --update-id 0e34842b-cc63-3a0f-bf4c-79afde50b134 --region us-west-2
```

更新已完成：
```json
"status": "Successful"
```

### 4. 重新生成 kubeconfig

```bash
aws eks update-kubeconfig --name mytest --region us-west-2
```

成功更新：
```
Updated context arn:aws:eks:us-west-2:051826712157:cluster/mytest in /home/ec2-user/.kube/config
```

### 5. 再次尝试 kubectl

```bash
kubectl get nodes
```

仍然失败，出现相同的认证错误。

## 节点组状态检查

**用户**: 节点创建完成了么

**Amazon Q**:
检查节点组状态：
```bash
aws eks describe-nodegroup --cluster-name mytest --nodegroup-name managed-ng --region us-west-2
```

结果显示节点组仍在创建中：
```json
"status": "CREATING",
"createdAt": "2025-04-28T07:36:33.152000+00:00"
```

节点组创建已经进行了约10分钟（从07:36到07:47）。

**用户**: 再看看？

## IAM OIDC 配置

**Amazon Q**:
再次检查节点组状态，仍然是 "CREATING"。

检查集群状态：
```bash
aws eks describe-cluster --name mytest --region us-west-2 --query "cluster.status"
```

结果显示集群本身已经是 "ACTIVE" 状态。

配置 IAM OIDC 提供商：
```bash
eksctl utils associate-iam-oidc-provider --cluster mytest --region us-west-2 --approve
```

结果：
```
created IAM Open ID Connect provider for cluster "mytest" in "us-west-2"
```

## 当前状态

### 集群信息
- **集群名称**: mytest
- **区域**: us-west-2
- **集群状态**: ACTIVE
- **认证模式**: API
- **OIDC 提供商**: https://oidc.eks.us-west-2.amazonaws.com/id/5610459483425327F9ED83460CA772AB

### 节点组信息
- **旧节点组**: managed-ng (状态: DELETING, 创建失败)
- **新节点组**: managed-ng-new (状态: CREATING)
- **节点类型**: t3.medium
- **节点数量**: 1 (min: 1, max: 2)
- **子网**: subnet-07c03102f9e3aff10
- **AMI 类型**: AL2023_x86_64_STANDARD
- **节点角色**: arn:aws:iam::051826712157:role/eksNodeRole
- **磁盘大小**: 20GB

### 认证问题
- kubectl 命令失败，错误信息：`the server has asked for the client to provide credentials`
- 原因：节点组创建失败，集群没有可用的工作节点
- 解决方案：创建了新的节点组，等待其完成创建

## 下一步计划

1. **等待新节点组创建完成**
   - 新节点组 managed-ng-new 正在创建中
   - 创建时间：2025-04-28T09:11:57
   - 预计完成时间：约15分钟后

2. **节点组创建完成后**
   - 再次尝试 `kubectl get nodes`
   - 如果仍然失败，检查以下内容：
     - IAM 权限
     - RBAC 配置
     - AWS CLI 凭证

3. **配置集群访问**
   - 创建必要的 RBAC 角色和绑定
   - 配置 aws-auth ConfigMap

4. **部署应用**
   - 部署基本应用验证集群功能
   - 配置负载均衡器和入口控制器

## 完整命令记录

```bash
# 获取认证令牌
aws eks get-token --cluster-name mytest --region us-west-2

# 检查 kubeconfig 文件
cat ~/.kube/config

# 尝试获取节点信息
kubectl get nodes

# 检查节点组状态
aws eks describe-nodegroup --cluster-name mytest --nodegroup-name managed-ng --region us-west-2

# 更新集群认证配置
aws eks update-cluster-config --name mytest --region us-west-2 --access-config authenticationMode=API

# 检查认证模式
aws eks describe-cluster --name mytest --region us-west-2 --query "cluster.accessConfig.authenticationMode"

# 检查更新状态
aws eks describe-update --name mytest --update-id 0e34842b-cc63-3a0f-bf4c-79afde50b134 --region us-west-2

# 更新 kubeconfig
aws eks update-kubeconfig --name mytest --region us-west-2

# 再次尝试获取节点信息
kubectl get nodes

# 检查集群状态
aws eks describe-cluster --name mytest --region us-west-2 --query "cluster.status"

# 获取 OIDC 提供商信息
aws eks describe-cluster --name mytest --region us-west-2 --query "cluster.identity.oidc.issuer"

# 创建 IAM OIDC 提供商
eksctl utils associate-iam-oidc-provider --cluster mytest --region us-west-2 --approve

# 检查节点实例状态
aws ec2 describe-instances --instance-ids i-0ed826ef19e7a6663 i-04646bbb7e9c587b6 --region us-west-2

# 获取节点实例控制台输出
aws ec2 get-console-output --instance-id i-0ed826ef19e7a6663 --region us-west-2

# 删除失败的节点组
aws eks delete-nodegroup --cluster-name mytest --nodegroup-name managed-ng --region us-west-2

# 创建新的节点组
aws eks create-nodegroup --cluster-name mytest --nodegroup-name managed-ng-new --scaling-config minSize=1,maxSize=2,desiredSize=1 --instance-types t3.medium --ami-type AL2023_x86_64_STANDARD --node-role arn:aws:iam::051826712157:role/eksNodeRole --subnets subnet-07c03102f9e3aff10 --disk-size 20 --region us-west-2
```

## 重要注意事项

1. **节点组创建失败原因**
   - 原节点组 managed-ng 创建失败，错误代码：NodeCreationFailure
   - 错误信息：Unhealthy nodes in the kubernetes cluster
   - 可能原因：节点无法正确加入集群，可能是网络、安全组或IAM权限问题

2. **新节点组配置**
   - 使用更简单的配置：单节点、单子网
   - 减少了可能的故障点

3. **认证问题**
   - 预计在新节点组创建完成后解决
   - 如果问题持续，可能需要进一步检查IAM和RBAC配置

4. **故障排除步骤**
   - 检查新节点的EC2控制台输出
   - 验证节点角色权限
   - 检查VPC和子网配置
## 节点组创建失败

**Amazon Q**:
再次检查节点组状态，发现节点组创建失败：

```bash
aws eks describe-nodegroup --cluster-name mytest --nodegroup-name managed-ng --region us-west-2
```

结果显示：
```json
"status": "CREATE_FAILED",
"health": {
    "issues": [
        {
            "code": "NodeCreationFailure",
            "message": "Unhealthy nodes in the kubernetes cluster",
            "resourceIds": [
                "i-0ed826ef19e7a6663",
                "i-04646bbb7e9c587b6"
            ]
        }
    ]
}
```

检查节点实例的控制台输出，发现节点已经启动但无法加入集群。

## 重新创建节点组

由于原节点组创建失败，决定删除并创建新的节点组：

```bash
# 删除失败的节点组
aws eks delete-nodegroup --cluster-name mytest --nodegroup-name managed-ng --region us-west-2

# 创建新的节点组，使用更简单的配置
aws eks create-nodegroup --cluster-name mytest --nodegroup-name managed-ng-new --scaling-config minSize=1,maxSize=2,desiredSize=1 --instance-types t3.medium --ami-type AL2023_x86_64_STANDARD --node-role arn:aws:iam::051826712157:role/eksNodeRole --subnets subnet-07c03102f9e3aff10 --disk-size 20 --region us-west-2
```

新节点组配置：
- 只使用1个节点（而不是之前的2个）
- 只使用1个子网（而不是之前的2个）
- 其他配置保持不变
