data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}

locals {
  instance_names = [for i in range(1, 5) : "ge-test${i}"] # 1부터 10까지의 인스턴스 이름 생성, 이름 변경 필요
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
  for_each = toset(local.instance_names)

  name        = "${each.key}-sg"
  description = "Allow SSH/HTTP for ${each.key}"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  lifecycle {
      ignore_changes = [ingress, egress]
  }

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
    Name = "${each.key}-sg"
  }
}

# 5. EC2 인스턴스 생성
resource "aws_instance" "web" {
  for_each = toset(local.instance_names)

  ami                         = "ami-03e38f46f79020a70" # Amazon Linux 2023 AMI (ap-northeast-2)
  instance_type               = "t3.small"
  subnet_id                   = data.terraform_remote_state.vpc.outputs.public_subnet_id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.keypair[each.key].key_name
  vpc_security_group_ids      = [aws_security_group.web_sg[each.key].id]

  user_data = <<-EOF
              #!/bin/bash
                sudo dnf update -y

              # Apache 설치 및 기동
                sudo dnf install -y httpd
                sudo systemctl enable httpd
                sudo systemctl start httpd
                echo "<h1>Hello from $(hostname)</h1>" | sudo tee /var/www/html/index.html

              # MySQL 공식 저장소 등록 및 GPG 우회 설치
                sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
                sudo dnf install -y mysql-community-server --nogpgcheck
                sudo systemctl enable mysqld
                sudo systemctl start mysqld
              EOF

  tags = {
    Name = each.key
  }
}

resource "aws_eip" "eip" {
  for_each = toset(local.instance_names)

  instance = aws_instance.web[each.key].id
}