provider "aws" {
  region = "ap-south-1"
}

module "vpc" {
  source     = "/home/ec2-user/generated/aws/ec2_instance/modules/vpc"
  cidr_block = var.vpc_cidr
}

module "ec2" {
  source        = "/home/ec2-user/generated/aws/ec2_instance/modules/ec2-instances"
  ami_id        = var.module_ami
  instance_type = var.module_in_type
  subnet_id     = module.vpc.public_subnet_id
}

module "s3" {
  source      = "/home/ec2-user/generated/aws/ec2_instance/modules/s3-bucket"
  bucket_name = var.module_s3_bkt_name
}

output "instance_id" {
  value = module.ec2.instance_id
}

output "bucket_arn" {
  value = module.s3.bucket_arn
}
