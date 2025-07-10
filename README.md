# 🦁 멋쟁이사자처럼 hackathon_terraform

Terraform을 활용한 해커톤용 AWS 인프라 자동화 구성

---

## ✅ 1. AWS CLI 설정
먼저 `aws configure`를 통해 Terraform 전체 운영을 위한 관리자 계정을 등록

---

## 🛠️ 2. 적용 순서
아래 순서대로 `terraform init` 및 `apply`를 실행

```
global → prod 폴더 → vpc → ec2 → iam
```
---

## 🖥️ 3. EC2 인스턴스 구성

- **구조**: 1티어

- **자동 설치 항목 (User Data)**  
  아래 두 가지 구성 중 선택하여 사용 가능

  ### ✅ 구성 1: Apache + MySQL
  - Apache Web Server
  - MySQL 8.0.42
  - 기본 HTML 경로: `/var/www/html/index.html`

  ### ✅ 구성 2: Nginx + Tomcat + MySQL
  - Nginx (리버스 프록시 적용)
  - Tomcat 9.0.91
  - MySQL 8.0.42
  - 기본 Nginx 경로: `/usr/share/nginx/html/index.html`
  - 기본 Tomcat 경로: `/opt/tomcat9/webapps/ROOT/index.jsp`

---

## 🔐 4. MySQL 초기 설정 방법

MySQL 설치 시 `root` 계정에 임시 암호가 설정  
인스턴스 접속 후 아래 절차에 따라 암호를 변경할 수 있도록 안내 필요

```bash
# 임시 비밀번호 확인
sudo grep 'temporary password' /var/log/mysqld.log

# MySQL 접속
mysql -u root -p

# 암호 변경
ALTER USER 'root'@'localhost' IDENTIFIED BY '변경할 암호';

# DB 및 사용자 계정 생성
CREATE DATABASE hackathon;
CREATE USER 'hackathon'@'localhost' IDENTIFIED BY 'hackathon';
GRANT ALL PRIVILEGES ON hackathon.* TO 'hackathon'@'localhost';
FLUSH PRIVILEGES;

=> 해당 설정은 hackathon이라는 DB와 전용 사용자 계정을 생성한 뒤, 해당 계정에 DB 전체 권한을 부여하고 이를 즉시 적용하는 설정
사용자가 원하는 방향으로 해당 세팅을 진행할 수 있도록 가이드 필요
```
---

## 👤 5. IAM 사용자 로그인 안내

- 생성된 IAM 사용자는 **초기 로그인 시 비밀번호 변경이 필수**
- 사용자가 임시 비밀번호로 로그인 후 **직접 비밀번호를 변경** 필요

📌 **글로벌 서비스 사용 및 비밀번호 변경을 위해 `us-east-1`(버지니아 북부) 리전 허용 필요**

현재 설정된 정책은 다음과 같음
- ✅ **허용**: 서울 리전(ap-northeast-2), 버지니아 북부(us-east-1), 글로벌 서비스(Route53, IAM, CloudFront 등)
- ❌ **차단**: 그 외 모든 리전에서의 리소스 생성, 확인, 삭제

---

## 📎 기타 참고사항
- EC2 인스턴스에 연결할 `.pem` 키는 `keys/` 폴더에 자동 저장
- 각 사용자에 대한 로그인 정보는 `credentials/` 폴더에 별도 텍스트 파일로 저장

---
