terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
}


# AWS S3 Bucket 생성
resource "aws_s3_bucket" "terraform_state" {
  bucket ="ge-terraform-test-backend" # 이름 변경
  tags = {
    Name = "terraform_state"
  }
  lifecycle {
    #prevent_destroy = true
  }
  force_destroy = true
}


resource "aws_kms_key" "terraform_state_kms" {
  description             = "terraform_state_kms"
  deletion_window_in_days = 7
}


resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_sec" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state_kms.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


resource "aws_s3_bucket_versioning" "terraform_state_ver" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "ge-test-terraform-bucket-lock" # 이름 변경
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# 로그 저장용 S3 버킷 생성
resource "aws_s3_bucket" "log_bucket" {
  bucket = "ge-test-terraform-logs" # 이름 변경

  tags = {
    Name = "terraform_log_bucket"
  }
}


# 계정 ID 조회용
data "aws_caller_identity" "current" {}

# S3 로그 버킷 정책
resource "aws_s3_bucket_policy" "log_bucket_policy" {
  bucket = aws_s3_bucket.log_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "logging.s3.amazonaws.com" },
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.log_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
}

# S3 버킷에 서버 액세스 로그 활성화
resource "aws_s3_bucket_logging" "terraform_state_logging" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}