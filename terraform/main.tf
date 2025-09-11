# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "kind-vpc"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's Owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  user_data_script_template = <<-EOF
    #!/bin/bash
    set -ex
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "--- Starting user data script at $(date) ---"

    # --- 1. KERNEL TUNING for Heavy Container Workload ---
    echo "Applying kernel tuning for stability..."
    cat << SYS_CTL | sudo tee /etc/sysctl.d/99-kubernetes-kind.conf
    fs.file-max = 1048576
    fs.inotify.max_user_watches = 524288
    fs.inotify.max_user_instances = 512
    vm.max_map_count = 262144
    net.ipv4.ip_forward = 1
    net.bridge.bridge-nf-call-iptables = 1
    SYS_CTL
    sudo sysctl --system

    # --- 2. Write instance-specific variables to a file for the sub-shell ---
    # These values are now passed in via the format() function
    cat << ENV_VARS | sudo tee /etc/instance_vars
    INSTANCE_INDEX=%d
    S3_BUCKET_NAME="%s"
    ENV_VARS

    # --- 3. Install Dependencies ---
    echo "Updating packages and installing dependencies..."
    sudo apt-get update -y
    sudo apt-get install -y curl apt-transport-https ca-certificates software-properties-common
    sudo snap install aws-cli --classic

    # --- 4. Install Docker & K8s Tools ---
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ubuntu

    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    echo "Installing kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind

    # --- 5. Switch to 'ubuntu' user to run the main logic ---
    sudo -i -u ubuntu bash <<'EOT'
    set -ex
    # Source the variables created by the root script
    source /etc/instance_vars

    echo "--- Running as 'ubuntu' user for instance $INSTANCE_INDEX and bucket $S3_BUCKET_NAME ---"

    # Calculate which cluster and task numbers this instance is responsible for
    CLUSTER_NUM_1=$((INSTANCE_INDEX * 2 + 1))
    CLUSTER_NUM_2=$((INSTANCE_INDEX * 2 + 2))
    CLUSTERS_TO_PROCESS=("$CLUSTER_NUM_1" "$CLUSTER_NUM_2")

    # --- 6. Create 2 KIND Clusters Sequentially ---
    echo "This instance will create clusters: $${CLUSTERS_TO_PROCESS[@]}"
    for i in "$${CLUSTERS_TO_PROCESS[@]}"; do
      CLUSTER_NAME="cluster$i"
      echo "======================================================================"
      echo "--- Starting creation of $CLUSTER_NAME ---"
      
      # UPDATED KIND_CONFIG for single control-plane node
      kind create cluster --name "$CLUSTER_NAME" --config - <<KIND_CONFIG
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
    KIND_CONFIG
      
      echo "Waiting for control plane of $CLUSTER_NAME to be ready..."
      CONTROL_PLANE_NODE_NAME="$CLUSTER_NAME-control-plane"
      kubectl wait --for=condition=Ready "node/$CONTROL_PLANE_NODE_NAME" --context="kind-$CLUSTER_NAME" --timeout=5m
      echo "--- Successfully created and validated $CLUSTER_NAME ---"
      
      echo "Pausing for 30 seconds to allow system to stabilize..."
      sleep 30
    done
    echo "All cluster creation loops for this instance are complete."

    # --- 7. Download and Apply Manifests for each Cluster ---
    echo "======================================================================"
    echo "Downloading and applying manifests for clusters: $${CLUSTERS_TO_PROCESS[@]}"
    export KUBECONFIG=~/.kube/config

    for i in "$${CLUSTERS_TO_PROCESS[@]}"; do
      TASK_DIR="task$i"
      CLUSTER_NAME="cluster$i"
      CONTEXT_NAME="kind-$CLUSTER_NAME"
      LOCAL_MANIFEST_DIR="/tmp/$${TASK_DIR}_manifests"
      # FIXED: Changed "manifest" to "manifests" to match your S3 structure.
      S3_MANIFEST_PATH="s3://$${S3_BUCKET_NAME}/$${TASK_DIR}/manifests/"

      echo "--- Processing $TASK_DIR for cluster $CLUSTER_NAME ---"
      
      rm -rf "$LOCAL_MANIFEST_DIR"
      mkdir -p "$LOCAL_MANIFEST_DIR"

      # UPDATED: Added robust error checking for the S3 copy command.
      echo "Attempting to download manifests from $S3_MANIFEST_PATH to $LOCAL_MANIFEST_DIR"
      if ! aws s3 cp --recursive "$S3_MANIFEST_PATH" "$LOCAL_MANIFEST_DIR"; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "ERROR: Failed to download manifests from S3 for $TASK_DIR."
        echo "Please check the following:"
        echo "1. The S3 bucket '$S3_BUCKET_NAME' exists and is accessible."
        echo "2. The exact path '$S3_MANIFEST_PATH' exists in the bucket."
        echo "3. The IAM role has the correct permissions."
        echo "Skipping manifest application for this cluster."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        continue # Skip to the next cluster
      fi
      
      echo "Listing downloaded files for $TASK_DIR:"
      ls -lR "$LOCAL_MANIFEST_DIR"

      if [ -n "$(ls -A "$LOCAL_MANIFEST_DIR")" ]; then
        echo "Switching context to $CONTEXT_NAME"
        kubectl config use-context "$CONTEXT_NAME"
        
        echo "--- Applying all manifests in $LOCAL_MANIFEST_DIR for $CLUSTER_NAME ---"

        kubectl apply -f "$LOCAL_MANIFEST_DIR/namespace.yaml"
        kubectl apply -f "$LOCAL_MANIFEST_DIR"

        
        
        echo "--- Verification for $CLUSTER_NAME: Listing all resources ---"
        sleep 5
        kubectl get all --all-namespaces
      else
        # This block will now likely only be reached if the manifest folder exists but is empty.
        echo "Warning: No manifest files were found in $S3_MANIFEST_PATH, even though the directory was accessible. Skipping apply for $CLUSTER_NAME."
      fi
      echo "--- Finished processing $TASK_DIR ---"
    done

    echo "--- All manifests application loops completed for this instance ---"
    EOT

    echo "--- User data script completed at $(date) ---"
    EOF
}




# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "kind-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "kind-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "kind-public-rt"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group (SSH + KIND ports; adjust as needed)
resource "aws_security_group" "kind_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For KIND exposed services
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kind-sg"
  }
}



# IAM role that allows the EC2 service to assume it
resource "aws_iam_role" "ec2_s3_read_role" {
  name = "ec2-s3-manifest-read-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2S3ManifestReadRole"
  }
}

# IAM policy that grants read-only access to a specific S3 bucket
resource "aws_iam_policy" "s3_read_policy" {
  name        = "s3-manifest-read-policy"
  description = "Allows reading k8s manifest files from the designated S3 bucket"

  # This policy now allows reading from any folder starting with "task"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/task*/*"
        ]
      }
    ]
  })
}

# Attach the read policy to the role
resource "aws_iam_role_policy_attachment" "attach_s3_read" {
  role       = aws_iam_role.ec2_s3_read_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# Create an instance profile to attach the role to the EC2 instance
resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3-manifest-access-profile"
  role = aws_iam_role.ec2_s3_read_role.name
}

# EC2 Spot Instance
resource "aws_instance" "kind_instance" {
  count = 3

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.kind_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.s3_access_profile.name

  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price                      = var.spot_price
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  # Use the local variable and format() to pass dynamic values to the script.
  user_data = format(local.user_data_script_template, count.index, var.s3_bucket_name)

  tags = {
    Name = "debug-kind-instance-${count.index + 1}"
  }
}

# Output the public IP for SSH access
output "instance_public_ips" {
  description = "A list of public IP addresses for the created EC2 instances."
  value       = aws_instance.kind_instance.*.public_ip
}




