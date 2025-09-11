variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "r7a.large"
}

variable "ami" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-0e86e20dae9224db8"  # Ubuntu 22.04 in us-east-1; update via AWS console or SSM parameter
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "my-key-pair"  # Create this in AWS first
}

variable "spot_price" {
  description = "Max spot price (optional, omit for on-demand pricing)"
  type        = string
  default     = "0.10"  # Adjust based on region and type
}


variable "s3_bucket_name" {
  description = "Name of the S3 bucket containing k8s manifest files"
  type        = string 
}