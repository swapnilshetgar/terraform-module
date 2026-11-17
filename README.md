# Terraform Modular Infrastructure

This project demonstrates how to create AWS infrastructure using **reusable Terraform modules**.

The project uses separate modules for:

- VPC
- EC2
- S3

It also demonstrates how values flow from the **root module → child modules** using Terraform variables and how values are returned using module outputs.

---

## Project Structure

```text
terraform-project/
│
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
│
└── modules/
    │
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── ec2-instances/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── s3-bucket/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

# 1. Root Module

The root module is the main entry point of the Terraform project.

The root module contains:

```text
main.tf
variables.tf
terraform.tfvars
outputs.tf
```

### `main.tf`

The root `main.tf` calls the child modules.

Example:

```hcl
provider "aws" {
  region = "ap-south-1"
}

module "vpc" {
  source     = "./modules/vpc"
  cidr_block = var.vpc_cidr
}

module "ec2" {
  source        = "./modules/ec2-instances"
  ami_id        = var.ami_id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_id
}

module "s3" {
  source      = "./modules/s3-bucket"
  bucket_name = var.bucket_name
}
```

---

# 2. Root `variables.tf`

The root `variables.tf` defines variables that are supplied to the root module.

Example:

```hcl
variable "vpc_cidr" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "bucket_name" {
  type = string
}
```

The root variables can receive values from `terraform.tfvars`.

---

# 3. `terraform.tfvars`

`terraform.tfvars` contains the actual values for the root variables.

Example:

```hcl
vpc_cidr      = "10.0.0.0/16"
ami_id        = "ami-04b0b8ee9ce90920a"
instance_type = "t3.micro"
bucket_name   = "sapi-bkt-test-1"
```

Terraform automatically loads `terraform.tfvars` when running:

```bash
terraform plan
```

or:

```bash
terraform apply
```

### Important

`terraform.tfvars` is normally kept at the **root level**.

You generally do not create a separate `terraform.tfvars` inside every child module.

---

# 4. Child Module

A child module is a reusable Terraform component.

For example:

```text
modules/ec2-instances/
```

contains:

```text
main.tf
variables.tf
outputs.tf
```

---

# 5. EC2 Module

## `modules/ec2-instances/main.tf`

```hcl
resource "aws_instance" "my_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = {
    Name = "ExampleEC2"
  }
}
```

## `modules/ec2-instances/variables.tf`

```hcl
variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}
```

These variables define the inputs that the EC2 module expects.

## `modules/ec2-instances/outputs.tf`

```hcl
output "instance_id" {
  value = aws_instance.my_instance.id
}
```

The output makes the EC2 instance ID available to the root module.

It can be accessed using:

```hcl
module.ec2.instance_id
```

---

# 6. S3 Module

## `modules/s3-bucket/main.tf`

```hcl
resource "aws_s3_bucket" "my_bkt" {
  bucket        = var.bucket_name
  force_destroy = true
}
```

## `modules/s3-bucket/variables.tf`

```hcl
variable "bucket_name" {
  type = string
}
```

## `modules/s3-bucket/outputs.tf`

```hcl
output "bucket_arn" {
  value = aws_s3_bucket.my_bkt.arn
}
```

The bucket ARN can be accessed from the root module using:

```hcl
module.s3.bucket_arn
```

---

# 7. Root Outputs

The root `outputs.tf` can expose values returned by child modules.

Example:

```hcl
output "instance_id" {
  value = module.ec2.instance_id
}

output "bucket_arn" {
  value = module.s3.bucket_arn
}
```

The flow is:

```text
EC2 Resource
     ↓
EC2 Module Output
     ↓
module.ec2.instance_id
     ↓
Root Output
```

---

# 8. Variable Flow

Terraform module variable flow is important to understand.

```text
terraform.tfvars
       ↓
Root variables.tf
       ↓
Root main.tf
       ↓
Module Input
       ↓
Child Module variables.tf
       ↓
Child Module main.tf
       ↓
AWS Resource
```

For example:

```text
terraform.tfvars
       ↓
ami_id = "ami-xxxx"
       ↓
var.ami_id
       ↓
module "ec2"
       ↓
ami_id = var.ami_id
       ↓
Child module variable "ami_id"
       ↓
var.ami_id
       ↓
aws_instance
```

---

# 9. Root Variable vs Module Variable

The root variable and child module variable **do not have to have the same name**.

Example:

### Root

```hcl
variable "module_ami" {
  type = string
}
```

### Root `main.tf`

```hcl
module "ec2" {
  source = "./modules/ec2-instances"

  ami_id = var.module_ami
}
```

### Child module

```hcl
variable "ami_id" {
  type = string
}
```

This is valid.

Here:

```text
Root variable             Child module variable

module_ami    ──────────→ ami_id
```

However, keeping the same logical name is usually easier to read:

```text
terraform.tfvars
     ↓
ami_id
     ↓
root main.tf
     ↓
ami_id
     ↓
EC2 module
```

---

# 10. Module Inputs and Outputs

### Inputs

Inputs go from the parent/root module into the child module.

```text
Root
  ↓
Child Module
```

Example:

```hcl
module "ec2" {
  ami_id = var.ami_id
}
```

### Outputs

Outputs go from the child module back to the parent/root module.

```text
Child Module
  ↓
Root
```

Example:

```hcl
output "instance_id" {
  value = aws_instance.my_instance.id
}
```

Then:

```hcl
module.ec2.instance_id
```

can be used by the root module.

---

# 11. Why Use Root `variables.tf`?

The root variables allow the infrastructure configuration to be changed without modifying the module code.

For example:

```hcl
ami_id        = "ami-xxxx"
instance_type = "t3.micro"
```

can be changed to:

```hcl
ami_id        = "ami-yyyy"
instance_type = "t3.large"
```

without modifying:

```text
modules/ec2-instances/main.tf
```

This makes the module reusable.

---

# 12. Why Use Modules?

Modules provide:

- Reusability
- Cleaner Terraform code
- Separation of infrastructure components
- Easier maintenance
- Consistent infrastructure
- Environment-specific configuration
- Easier team collaboration

For example, the same EC2 module can be reused for:

```text
Development
Testing
Staging
Production
```

with different variable values.

---

# 13. Terraform Commands

Initialize the project:

```bash
terraform init
```

Format Terraform files:

```bash
terraform fmt -recursive
```

Validate configuration:

```bash
terraform validate
```

Preview changes:

```bash
terraform plan
```

Create infrastructure:

```bash
terraform apply
```

Destroy infrastructure:

```bash
terraform destroy
```

---

# 14. Important Terraform Concept

A child module does **not automatically read the root `terraform.tfvars`**.

The values must be passed through the module block.

Correct:

```hcl
module "ec2" {
  source = "./modules/ec2-instances"

  ami_id        = var.ami_id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_id
}
```

The child module receives those values through:

```hcl
variable "ami_id" {}
variable "instance_type" {}
variable "subnet_id" {}
```

---

# 15. Recommended Module Structure

For reusable modules, the common structure is:

```text
modules/
└── ec2/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### `main.tf`

Contains resources.

### `variables.tf`

Contains module inputs.

### `outputs.tf`

Contains values returned by the module.

A `terraform.tfvars` file is generally **not required inside the module**.

---

# 16. Final Architecture

```text
                    ROOT MODULE
        ┌─────────────────────────────┐
        │                             │
        │ terraform.tfvars            │
        │        ↓                    │
        │ variables.tf                │
        │        ↓                    │
        │ main.tf                     │
        │        │                    │
        └────────┼────────────────────┘
                 │
       ┌─────────┼─────────┐
       ↓         ↓         ↓
     VPC        EC2        S3
   MODULE     MODULE     MODULE
       │         │         │
       ↓         ↓         ↓
    outputs   outputs   outputs
       │         │         │
       └─────────┼─────────┘
                 ↓
             ROOT OUTPUTS
```

---

## Key Rules to Remember

1. **`terraform.tfvars` normally belongs to the root module.**
2. **Child modules normally contain `main.tf`, `variables.tf`, and `outputs.tf
