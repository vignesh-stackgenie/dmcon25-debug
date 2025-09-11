region       = "us-east-1"
vpc_cidr     = "10.0.0.0/16"
subnet_cidr  = "10.0.1.0/24"
instance_type = "r7a.large"
#ami          = "ami-0e86e20dae9224db8"  
key_name     = "vignesh_key"
spot_price   = "0.20"


s3_bucket_name = "k8s-manifests-bucket"