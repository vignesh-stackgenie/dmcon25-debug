# Terraform Infrastructure for Kubernetes Debugging Labs

This Terraform configuration creates a distributed Kubernetes debugging environment using AWS EC2 spot instances. The setup includes three EC2 instances, each running two KinD (Kubernetes in Docker) clusters, creating a total of six Kubernetes clusters for different debugging scenarios.

## Infrastructure Overview

- 3 EC2 spot instances
- Each instance runs 2 KinD clusters (total 6 clusters)
- Kubernetes manifests stored in S3 bucket
- Automatic installation of Docker, kubectl, and KinD
- Each cluster runs different debugging scenarios

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0.0
3. S3 bucket containing Kubernetes manifests
4. AWS IAM permissions for:
   - EC2 spot instances
   - S3 bucket access
   - VPC/networking operations

## Directory Structure

```
terraform/
├── main.tf          # Main Terraform configuration
├── variables.tf     # Variable definitions
├── provider.tf      # AWS provider configuration
├── user_data.sh     # Instance bootstrap script
└── terraform.tfvars # Variable values
```

## Resource Creation

1. **VPC and Networking**
   - VPC with public subnets
   - Security Groups
   - Internet Gateway

2. **EC2 Spot Instances**
   - Instance type: t3.medium
   - Amazon Linux 2
   - Spot request configuration
   - IAM role for S3 access

3. **Bootstrap Configuration**
   - Installation of Docker
   - Installation of kubectl
   - Installation of KinD
   - Creation of two KinD clusters
   - Fetching manifests from S3
   - Applying debugging scenarios

## Usage

1. Configure AWS credentials:
```bash
export AWS_PROFILE=your-profile
```

2. Initialize Terraform:
```bash
terraform init
```

3. Review the plan:
```bash
terraform plan
```

4. Apply the configuration:
```bash
terraform apply
```

5. Destroy the infrastructure:
```bash
terraform destroy
```

## Instance Configuration

Each EC2 instance is configured with:

```bash
# System updates
- Latest Amazon Linux 2 updates
- Required system packages

# Docker Installation
- Docker CE
- Docker service enabled
- User added to docker group

# Kubernetes Tools
- kubectl (latest stable)
- KinD binary
- AWS CLI

# Cluster Setup
- Two KinD clusters per instance
- Unique cluster names
- Different port mappings

# Manifest Deployment
- S3 bucket access
- Manifest download
- Scenario deployment
```

## KinD Cluster Configuration

Each instance creates two clusters:
```yaml
# First Cluster
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cluster1
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000

# Second Cluster
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cluster2
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30001
    hostPort: 30001
```

## Debugging Scenarios

Each cluster is configured with different debugging scenarios:

Instance 1:
- Cluster 1: Tasks 1 & 2
- Cluster 2: Tasks 3 & 4

Instance 2:
- Cluster 1: Tasks 5 & 6
- Cluster 2: Additional scenarios

Instance 3:
- Cluster 1: Reserved for custom scenarios
- Cluster 2: Reserved for custom scenarios

## Accessing the Clusters

1. SSH into the EC2 instance:
```bash
ssh -i your-key.pem ec2-user@instance-ip
```

2. List available clusters:
```bash
kind get clusters
```

3. Set kubectl context:
```bash
kubectl cluster-info --context kind-cluster1
kubectl cluster-info --context kind-cluster2
```

## Notes

- Spot instances may be terminated by AWS with 2-minute notice
- Data in KinD clusters is ephemeral
- S3 bucket must be properly configured with required manifests
- Security groups allow inbound SSH and required Kubernetes ports
- Each instance requires approximately 4GB RAM for two KinD clusters

## Troubleshooting

1. Check instance bootstrap logs:
```bash
sudo cat /var/log/cloud-init-output.log
```

2. Check Docker status:
```bash
sudo systemctl status docker
```

3. Check KinD clusters:
```bash
kind get clusters
docker ps
```

4. Check S3 access:
```bash
aws s3 ls s3://your-bucket/manifests/
```

## Clean Up

To avoid unnecessary charges:

1. Remove all resources:
```bash
terraform destroy -auto-approve
```

2. Verify spot instance termination
3. Check for any remaining ENIs or volumes
4. Verify S3 bucket contents if needed
