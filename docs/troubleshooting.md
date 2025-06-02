# Troubleshooting Guide

## Quick Diagnosis Commands

```bash
# Check AWS connectivity
aws sts get-caller-identity

# Check Terraform state
terraform show

# Check EKS cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Check AWS resources
aws eks describe-cluster --name CLUSTER_NAME
aws rds describe-db-instances
```

## 🚨 Common Issues and Solutions

### 1. Terraform Deployment Failures

#### Issue: "Error creating EKS cluster: AccessDenied"
**Symptoms**:
```
Error: error creating EKS Cluster: AccessDeniedException: 
User is not authorized to perform: eks:CreateCluster
```

**Cause**: Insufficient IAM permissions

**Solution**:
```bash
# Check your current permissions
aws sts get-caller-identity
aws iam get-user

# Required IAM policies for deployment:
# - EKSFullAccess
# - EC2FullAccess  
# - VPCFullAccess
# - IAMFullAccess
# - CloudWatchFullAccess
# - RDSFullAccess

# Add required policies to your user/role
aws iam attach-user-policy --user-name YOUR_USER --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

#### Issue: "Error creating RDS subnet group: InvalidSubnet"
**Symptoms**:
```
Error: Error creating DB Subnet Group: InvalidSubnet: 
Cannot create a subnet group with subnets in the same Availability Zone
```

**Cause**: Subnets configured in same AZ

**Solution**:
```hcl
# Fix in terraform.tfvars
availability_zones = ["us-west-2a", "us-west-2b"]  # Different AZs

# Verify AZs are different
aws ec2 describe-availability-zones --region us-west-2
```

#### Issue: "Error: timeout while waiting for state to become 'available'"
**Symptoms**: Terraform hangs for 30+ minutes

**Cause**: Resource creation taking longer than expected

**Solution**:
```bash
# Check AWS console for resource status
# Common causes:
# 1. EKS cluster creation (15-20 minutes normal)
# 2. RDS backup restoration
# 3. Security group dependencies

# If stuck, check AWS CloudTrail for errors
aws logs describe-log-groups --log-group-name-prefix "/aws/eks"
```

### 2. EKS Cluster Issues

#### Issue: "kubectl: connection refused"
**Symptoms**:
```bash
$ kubectl get nodes
The connection to the server localhost:8080 was refused
```

**Cause**: kubectl not configured for EKS cluster

**Solution**:
```bash
# Update kubeconfig
aws eks update-kubeconfig --region REGION --name CLUSTER_NAME

# Verify configuration
kubectl config current-context

# Test connection
kubectl get nodes
```

#### Issue: "Nodes not joining cluster"
**Symptoms**: 
```bash
$ kubectl get nodes
No resources found
```

**Cause**: Security group or IAM role misconfiguration

**Solution**:
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name CLUSTER_NAME --nodegroup-name NODEGROUP_NAME

# Check security groups allow traffic
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# Verify IAM roles have required policies
aws iam list-attached-role-policies --role-name EKS-NODE-GROUP-ROLE
```

#### Issue: "Pod stuck in Pending state"
**Symptoms**:
```bash
$ kubectl get pods
NAME     READY   STATUS    RESTARTS   AGE
app-xxx  0/1     Pending   0          5m
```

**Causes and Solutions**:

**Insufficient Resources**:
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check pod resource requests
kubectl describe pod POD_NAME

# Scale cluster if needed
kubectl patch deployment cluster-autoscaler -p '{"spec":{"replicas":1}}'
```

**Image Pull Errors**:
```bash
# Check pod events
kubectl describe pod POD_NAME

# Common solutions:
# 1. Fix image name/tag
# 2. Add image pull secrets for private registries
# 3. Check ECR permissions
```

### 3. Database Connection Issues

#### Issue: "Connection refused" to RDS
**Symptoms**:
```bash
psql: could not connect to server: Connection refused
```

**Cause**: Security group or network configuration

**Solution**:
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids RDS_SECURITY_GROUP_ID

# Security group should allow:
# - Port 5432 from EKS security group
# - Port 5432 from VPC CIDR (10.0.0.0/16)

# Test connectivity from EKS pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- psql -h RDS_ENDPOINT -U USERNAME -d DATABASE
```

#### Issue: "Too many connections" error
**Symptoms**:
```
FATAL: too many connections for role "username"
```

**Solution**:
```bash
# Check current connections
kubectl exec -it postgres-pod -- psql -c "SELECT count(*) FROM pg_stat_activity;"

# Solutions:
# 1. Implement connection pooling (PgBouncer)
# 2. Increase max_connections parameter
# 3. Fix connection leaks in application

# Temporary fix - restart application pods
kubectl rollout restart deployment YOUR_APP
```

### 4. Application Deployment Issues

#### Issue: "CrashLoopBackOff" status
**Symptoms**:
```bash
$ kubectl get pods
NAME     READY   STATUS             RESTARTS   AGE
app-xxx  0/1     CrashLoopBackOff   5          5m
```

**Solution**:
```bash
# Check pod logs
kubectl logs POD_NAME
kubectl logs POD_NAME --previous  # Previous container logs

# Check pod events
kubectl describe pod POD_NAME

# Common causes:
# 1. Wrong environment variables
# 2. Missing config files
# 3. Health check failures
# 4. Insufficient resources
```

#### Issue: "Service Unavailable" (503 errors)
**Symptoms**: External requests returning 503

**Solution**:
```bash
# Check service endpoints
kubectl get endpoints

# Check if pods are ready
kubectl get pods -o wide

# Check ingress/load balancer
kubectl get ingress
kubectl describe ingress YOUR_INGRESS

# Check service configuration
kubectl describe service YOUR_SERVICE
```

### 5. Monitoring and Alerting Issues

#### Issue: "No metrics in CloudWatch"
**Cause**: CloudWatch agent not configured

**Solution**:
```bash
# Install CloudWatch agent
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

# Verify agent is running
kubectl get pods -n amazon-cloudwatch
```

#### Issue: "Not receiving SNS alerts"
**Cause**: Email subscription not confirmed

**Solution**:
```bash
# Check subscription status
aws sns list-subscriptions-by-topic --topic-arn TOPIC_ARN

# Resend confirmation
aws sns subscribe --topic-arn TOPIC_ARN --protocol email --notification-endpoint your-email@company.com
```

## 🔧 Emergency Procedures

### Complete System Recovery
If everything fails and you need to start fresh:

```bash
# 1. Save any important data
kubectl get all --all-namespaces > backup-resources.yaml
terraform show > terraform-current-state.txt

# 2. Destroy everything
terraform destroy -auto-approve

# 3. Clean up any leftover resources manually
aws ec2 describe-instances --filters "Name=tag:Project,Values=YOUR_PROJECT"
aws rds describe-db-instances

# 4. Fresh deployment
./scripts/setup.sh
./scripts/deploy.sh

# 5. Restore applications (not infrastructure)
kubectl apply -f backup-resources.yaml
```

### Partial Recovery - EKS Only
If only Kubernetes is having issues:

```bash
# Reset EKS cluster (keeps RDS data)
terraform destroy -target=module.eks
terraform apply -target=module.eks

# Reconfigure kubectl
aws eks update-kubeconfig --region REGION --name CLUSTER_NAME
```

### Database Recovery
If RDS needs recovery:

```bash
# Check latest backup
aws rds describe-db-snapshots --db-instance-identifier YOUR_DB_INSTANCE

# Restore from backup (creates new instance)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier YOUR_DB_INSTANCE-restored \
  --db-snapshot-identifier rds:YOUR_DB_INSTANCE-YYYY-MM-DD-HH-MM
```

## 📞 Getting Help

### AWS Support
- **Basic**: Forums and documentation
- **Developer**: $29/month - business hours support
- **Business**: $100/month - 24/7 support
- **Enterprise**: $15,000/month - dedicated support

### Community Resources
- **GitHub Issues**: [Project Issues](https://github.com/your-username/startup-production-stack/issues)
- **AWS Forums**: https://forums.aws.amazon.com/
- **Kubernetes Slack**: https://kubernetes.slack.com/
- **Stack Overflow**: Tag questions with `aws-eks`, `terraform`, `kubernetes`

### Professional Services
- **AWS Professional Services**: Architecture review and optimization
- **Partner Network**: AWS certified consultants
- **Custom Support**: Available for enterprise implementations

## 🛠️ Debugging Tools

### Terraform Debugging
```bash
# Enable detailed logging
export TF_LOG=DEBUG
terraform plan

# Validate configuration
terraform validate

# Check state
terraform state list
terraform state show RESOURCE_NAME
```

### Kubernetes Debugging
```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide

# Pod debugging
kubectl describe pod POD_NAME
kubectl logs POD_NAME -f
kubectl exec -it POD_NAME -- /bin/bash

# Network debugging
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never
```

### AWS CLI Debugging
```bash
# Enable debug output
aws --debug ec2 describe-instances

# Check credentials
aws sts get-caller-identity

# Test connectivity
aws eks list-clusters
aws rds describe-db-instances
```

## ✅ Health Check Checklist

### Daily Checks
- [ ] All pods running: `kubectl get pods --all-namespaces`
- [ ] Cluster nodes healthy: `kubectl get nodes`
- [ ] No critical alerts in CloudWatch
- [ ] Application responding: `curl -I https://your-app.com`

### Weekly Checks  
- [ ] Review CloudWatch logs for errors
- [ ] Check resource utilization
- [ ] Verify backups are working
- [ ] Review security alerts

### Monthly Checks
- [ ] Update cluster version if needed
- [ ] Review and update dependencies
- [ ] Performance analysis
- [ ] Cost optimization review
- [ ] Security patches and updates

Remember: Most issues are configuration-related. Double-check your terraform.tfvars and ensure all prerequisites are met before deployment.
