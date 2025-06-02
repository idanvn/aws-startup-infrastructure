# Cost Optimization Guide

## Overview
This guide helps you optimize costs while maintaining performance and reliability for your startup infrastructure.

## 💰 Immediate Cost Reductions

### 1. Use Spot Instances (Save 60-90%)
Replace your regular node groups with spot instances for non-critical workloads:

**Current cost**: t3.medium on-demand = $30/month per instance
**With spot**: t3.medium spot = $9/month per instance
**Savings**: $21/month per instance

**Implementation:**
Edit your `terraform.tfvars`:
```hcl
# Add mixed instance policy
eks_node_groups = {
  main = {
    instance_types = ["t3.medium", "t3.large"]
    capacity_type  = "SPOT"
    scaling_config = {
      desired_size = 2
      max_size     = 10
      min_size     = 1
    }
  }
}
```

### 2. Right-Size Your Database
Start small and scale up as needed:

**Development Environment:**
```hcl
rds_instance_class = "db.t3.micro"     # $13/month vs $200/month for db.r5.large
rds_allocated_storage = 20             # $2.3/month vs $115/month for 1TB
```

**Production Environment (when you need it):**
```hcl
rds_instance_class = "db.t3.small"     # $26/month
rds_allocated_storage = 100            # $11.5/month
```

**Potential Savings**: $180/month by starting small

### 3. Development Environment Scheduling
Automatically stop development resources when not in use:

**Schedule A: Manual Scripts**
```bash
#!/bin/bash
# save as scripts/stop-dev.sh
aws eks update-nodegroup-config \
  --cluster-name dev-cluster \
  --nodegroup-name dev-nodes \
  --scaling-config minSize=0,maxSize=0,desiredSize=0

# save as scripts/start-dev.sh  
aws eks update-nodegroup-config \
  --cluster-name dev-cluster \
  --nodegroup-name dev-nodes \
  --scaling-config minSize=1,maxSize=5,desiredSize=2
```

**Schedule B: Cron Jobs**
```bash
# Stop at 7 PM weekdays
0 19 * * 1-5 /path/to/scripts/stop-dev.sh

# Start at 8 AM weekdays
0 8 * * 1-5 /path/to/scripts/start-dev.sh

# Stop Friday 7 PM (weekend)
0 19 * * 5 /path/to/scripts/stop-dev.sh

# Start Monday 8 AM
0 8 * * 1 /path/to/scripts/start-dev.sh
```

**Savings**: 70% reduction in development environment costs
- Nights: 13 hours × 5 days = 65 hours saved
- Weekends: 48 hours saved
- **Total**: 113 hours saved out of 168 hours/week = 67% savings

### 4. Storage Optimization
```hcl
# Already optimized in template - GP3 vs GP2
storage_type = "gp3"          # 20% cheaper than GP2
storage_encrypted = true      # No additional cost for encryption
iops = 3000                   # Free baseline, pay only for extra
throughput = 125              # Free baseline
```

## 🎯 Advanced Cost Optimizations

### Reserved Instances (Production Only)
**When to buy**: After 3+ months of stable usage

**Savings**:
- **1-year, No Upfront**: 40% discount
- **1-year, All Upfront**: 43% discount  
- **3-year, All Upfront**: 60% discount

**Example**:
- t3.large on-demand: $60/month
- t3.large 1-year reserved: $36/month
- **Savings**: $24/month × 12 = $288/year

### Kubernetes Resource Optimization

#### Set Resource Requests and Limits
```yaml
# Prevents over-provisioning
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"      # 0.05 CPU cores
          limits:
            memory: "128Mi"
            cpu: "100m"     # 0.1 CPU cores
```

#### Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: your-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Database Cost Optimization

#### Connection Pooling with PgBouncer
```yaml
# Reduces database connections = smaller RDS instance needed
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: pgbouncer
        image: pgbouncer/pgbouncer:latest
        env:
        - name: DATABASES_HOST
          value: "your-rds-endpoint"
        - name: POOL_MODE
          value: "transaction"
        - name: MAX_CLIENT_CONN
          value: "100"
        - name: DEFAULT_POOL_SIZE
          value: "20"
```

#### Read Replicas (Only When Needed)
```hcl
# Add read replica only for production with high read load
resource "aws_db_instance" "read_replica" {
  count = var.environment == "prod" && var.enable_read_replica ? 1 : 0
  
  identifier = "${var.project_name}-${var.environment}-read-replica"
  replicate_source_db = aws_db_instance.main.id
  instance_class = "db.t3.micro"  # Can be smaller than primary
}
```

## 📊 Cost Monitoring & Alerts

### AWS Budgets Setup
```bash
# Create budget via AWS CLI
aws budgets create-budget --account-id YOUR_ACCOUNT_ID --budget '{
  "BudgetName": "Startup-Stack-Monthly",
  "BudgetLimit": {
    "Amount": "200",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}' --notifications-with-subscribers '[{
  "Notification": {
    "NotificationType": "ACTUAL",
    "ComparisonOperator": "GREATER_THAN",
    "Threshold": 80
  },
  "Subscribers": [{
    "SubscriptionType": "EMAIL",
    "Address": "your-email@company.com"
  }]
}]'
```

### CloudWatch Billing Alarms
Add to your Terraform:
```hcl
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "${var.project_name}-billing-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # 24 hours
  statistic           = "Maximum"
  threshold           = "200"    # $200/month
  alarm_description   = "This metric monitors estimated billing charges"
  alarm_actions       = [aws_sns_topic.billing_alerts.arn]

  dimensions = {
    Currency = "USD"
  }
}
```

### Cost Analysis Tools

#### AWS Cost Explorer
- **Monthly Reports**: Review spending by service
- **Usage Reports**: Identify unused resources
- **Recommendations**: Right-sizing suggestions

#### Third-Party Tools
- **Kubecost**: Kubernetes cost monitoring
- **CloudHealth**: Multi-cloud cost management
- **Spot.io**: Automated spot instance management

## 🏆 Cost Optimization Checklist

### Daily (Automated)
- [ ] Cluster autoscaler active
- [ ] Unused volumes deleted
- [ ] Failed deployments cleaned up

### Weekly
- [ ] Review CloudWatch costs
- [ ] Check for unused security groups
- [ ] Verify backup retention settings

### Monthly  
- [ ] Analyze Cost Explorer reports
- [ ] Review and adjust resource sizes
- [ ] Evaluate reserved instance opportunities
- [ ] Clean up old AMIs and snapshots

### Quarterly
- [ ] Review architecture for cost optimization
- [ ] Evaluate new AWS cost-saving features
- [ ] Consider service alternatives (e.g., Fargate vs EKS)

## 💡 Pro Tips

1. **Tag Everything**: Use consistent tagging for cost allocation
2. **Use AWS Calculator**: Estimate costs before deploying
3. **Monitor Trends**: Set up weekly cost reports
4. **Automate Cleanup**: Use lifecycle policies for logs and backups
5. **Review Regularly**: Monthly cost reviews prevent surprises

## Expected Savings Summary

| Optimization | Monthly Savings | Implementation Effort |
|-------------|-----------------|---------------------|
| Spot Instances | $50-100 | Low |
| Right-sizing DB | $150-180 | Low |  
| Dev Scheduling | $75-100 | Medium |
| Reserved Instances | $50-200 | Low |
| Resource Limits | $25-50 | Medium |
| **Total Potential** | **$350-630** | **Medium** |

**ROI**: 2-4 hours setup can save $300+ monthly = $3,600+ yearly
