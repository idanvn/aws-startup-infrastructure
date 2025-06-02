#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TERRAFORM_DIR="terraform"

echo -e "${RED}"
echo "🗑️  Destroying Production-Ready Startup Stack"
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

# Check if running from correct directory
if [ ! -f "README.md" ] || [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    print_error "terraform.tfvars not found. Nothing to destroy."
    exit 1
fi

cd "$TERRAFORM_DIR"

# Show what will be destroyed
print_warning "This will PERMANENTLY DELETE all infrastructure including:"
echo "  🗄️  Databases (with all data)"
echo "  🔧 EKS clusters (and all workloads)"
echo "  🌐 VPCs and networking"
echo "  📊 CloudWatch logs and metrics"
echo "  💾 All associated storage"
echo ""

PROJECT_NAME=$(grep project_name terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "unknown")
print_warning "Project: $PROJECT_NAME"

echo ""
print_error "THIS ACTION CANNOT BE UNDONE!"
echo ""

read -p "Type 'destroy' to confirm: " CONFIRM
if [ "$CONFIRM" != "destroy" ]; then
    echo "Destruction cancelled."
    exit 0
fi

print_status "Creating destruction plan..."
terraform plan -destroy

echo ""
read -p "Proceed with destruction? (yes/no): " FINAL_CONFIRM
if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

print_status "Destroying infrastructure..."
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    print_status "Infrastructure destroyed successfully!"
    echo ""
    echo "Cleanup completed. All AWS resources have been removed."
else
    print_error "Destruction failed! Some resources may still exist."
    echo "Please check the AWS console and remove resources manually if needed."
    exit 1
fi

cd ..
