#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TERRAFORM_DIR="terraform"

echo -e "${BLUE}"
echo "🚀 Deploying Production-Ready Startup Stack"
echo "=============================================="
echo -e "${NC}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if running from correct directory
if [ ! -f "README.md" ] || [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check if setup was run
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    print_error "terraform.tfvars not found. Please run ./scripts/setup.sh first"
    exit 1
fi

if [ ! -f "$TERRAFORM_DIR/tfplan" ]; then
    print_error "Terraform plan not found. Please run ./scripts/setup.sh first"
    exit 1
fi

# Parse command line arguments
ENVIRONMENT=${1:-dev}
AUTO_APPROVE=${2:-false}

if [ "$AUTO_APPROVE" != "true" ]; then
    # Show what will be deployed
    print_info "Deployment Summary:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Region: $(grep aws_region $TERRAFORM_DIR/terraform.tfvars | cut -d'"' -f2)"
    echo "  Project: $(grep project_name $TERRAFORM_DIR/terraform.tfvars | cut -d'"' -f2)"
    echo ""
    echo "This will create:"
    echo "  ✅ VPC with public/private subnets"
    echo "  ✅ EKS cluster with managed node groups"
    echo "  ✅ RDS PostgreSQL database"
    echo "  ✅ ElastiCache Redis cluster"
    echo "  ✅ CloudWatch monitoring and alerting"
    echo "  ✅ Security groups and IAM roles"
    echo ""
    print_warning "Estimated cost: ~\$5-15/day depending on usage"
    echo ""
    
    read -p "Do you want to proceed? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

cd "$TERRAFORM_DIR"

# Deploy infrastructure
print_status "Deploying infrastructure..."
echo "This may take 15-20 minutes..."

START_TIME=$(date +%s)

if [ "$AUTO_APPROVE" = "true" ]; then
    terraform apply -auto-approve tfplan
else
    terraform apply tfplan
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

if [ $? -eq 0 ]; then
    print_status "Infrastructure deployed successfully in ${MINUTES}m ${SECONDS}s!"
else
    print_error "Deployment failed!"
    exit 1
fi

# Get outputs
print_status "Retrieving deployment information..."

EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || grep aws_region terraform.tfvars | cut -d'"' -f2)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")

cd ..

echo -e "${GREEN}"
echo "🎉 Deployment completed successfully!"
echo "======================================"
echo -e "${NC}"

if [ ! -z "$EKS_CLUSTER_NAME" ]; then
    echo "📋 Next Steps:"
    echo ""
    echo "1. Configure kubectl:"
    echo "   aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME"
    echo ""
    echo "2. Verify cluster:"
    echo "   kubectl get nodes"
    echo ""
    echo "3. Deploy your application:"
    echo "   kubectl create deployment nginx --image=nginx"
    echo "   kubectl expose deployment nginx --port=80 --type=LoadBalancer"
    echo ""
fi

echo "📊 Monitoring & Management:"
if [ ! -z "$AWS_REGION" ]; then
    echo "   CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION"
    echo "   EKS Console: https://console.aws.amazon.com/eks/home?region=$AWS_REGION#/clusters"
fi

if [ ! -z "$RDS_ENDPOINT" ]; then
    echo ""
    echo "🗄️  Database Information:"
    echo "   Endpoint: $RDS_ENDPOINT"
    echo "   Credentials stored in AWS Secrets Manager"
    echo ""
fi

echo "💰 Cost Management:"
echo "   Monitor costs: https://console.aws.amazon.com/billing/home#/"
echo "   Set up budget alerts to avoid surprises"
echo ""

echo "🆘 Support:"
echo "   Documentation: ./docs/"
echo "   Issues: https://github.com/your-username/startup-production-stack/issues"
echo ""

print_warning "Don't forget to destroy resources when not needed: terraform destroy"
