<멋쟁이사자처럼 hackathon_terraform>
1. 먼저 AWS Configure를 통해 Terraform 전체 운영을 위한 관리자 계정을 등록해주세요.

2. 순서대로 init 및 apply 진행해주세요.
global -> Dev 폴더 -> vpc -> ec2 -> iam

3. 인스턴스는 1tier 구조로 유저 데이터를 통해 Apache와 Mysql가 자동 설치됩니다.
mysql Ver: 8.0.42

4. Myslq의 경우 설치시 root 계정에 임시 암호가 세팅되어 있으므로, 아래 명령어를 통해 인스턴스 접속 후 해당 암호를 변경해서 사용하도록 안내해주세요.
    # 임시암호 확인 명령어
    sudo grep 'temporary password' /var/log/mysqld.log

    # mysql 접속 명령어
    mysql -u root -p

    # 루트 암호 변경
    ALTER USER 'root'@'localhost' IDENTIFIED BY '변경할 암호';

5. iam의 경우 사용자 지정 암호 사용이 불가하며, 반드시 첫 로그인을 통해 임시 암호에서 사용자가 원하는 암호로 변경하도록 되어 있습니다.
글로벌 서비스 사용 및 콘솔 로그인 암호 변경을 위해서는 버지니아 북부 리전의 사용이 활성화되어야 합니다.
따라서 현재 리전 제한 정책은 서울 리전과 버지니아 북부를 제외한 모든 리전에서의 리소스 생성 및 확인, 삭제가 불가하도록 구성되어있습니다.
참고해주세요!


