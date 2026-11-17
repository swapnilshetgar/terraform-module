resource "aws_s3_bucket" "my_bkt" {
  bucket        = var.bucket_name
  force_destroy = true
}

