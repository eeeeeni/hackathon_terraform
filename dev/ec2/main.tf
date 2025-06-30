data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}

locals {
  instance_names = [for i in range(1, 11) : "ge-test${i}"] # 1부터 10까지의 인스턴스 이름 생성, 이름 및 range 값 조정 필요
}

# 1. TLS 키 생성 (개별 인스턴스용)
resource "tls_private_key" "key" {
  for_each = toset(local.instance_names)

  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. 키페어 등록 (AWS에 공개키 업로드)
resource "aws_key_pair" "keypair" {
  for_each = tls_private_key.key

  key_name   = each.key
  public_key = each.value.public_key_openssh
}

# 3. 로컬에 .pem 파일 저장 (비공개키 저장)
resource "local_file" "private_key" {
  for_each = tls_private_key.key

  content              = each.value.private_key_pem
  filename             = "${path.module}/keys/${each.key}.pem"
  file_permission      = "0600"
  directory_permission = "0700"
}

# 4. 보안 그룹 (포트 22/80/443 오픈)
resource "aws_security_group" "web_sg" {
  name        = "ge-test-web-sg" # 보안 그룹 이름 변경
  description = "Allow SSH/HTTP/HTTPS"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

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
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
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
    Name = "web-sg"
  }
}

# 5. EC2 인스턴스 생성
resource "aws_instance" "web" {
  for_each = toset(local.instance_names)

  ami                         = "ami-0c9c942bd7bf113a2" # web+db 포함된 1티어 이미지로 수정 필요
  instance_type               = "t3.medium"
  subnet_id                   = data.terraform_remote_state.vpc.outputs.public_subnet_id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.keypair[each.key].key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "Hello from ${each.key}" > /var/www/html/index.html
              EOF

  tags = {
    Name = each.key
  }
}