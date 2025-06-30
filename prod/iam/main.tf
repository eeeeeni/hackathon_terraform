locals {
  usernames = [for i in range(1, 61) : "ge-testuser${i}"] # 1부터 60까지 유저 생성, 이름 변경 필요
}

# 1. IAM 사용자 생성
resource "aws_iam_user" "users" {
  for_each = toset(local.usernames)
  name     = each.key
}

# 2. 차단 정책 문서 (서울/글로벌 제외 모든 리전 Deny)
data "aws_iam_policy_document" "deny_other_regions" {
  statement {
    sid    = "DenyAllOtherRegions"
    effect = "Deny"
    actions = ["*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values = [
        "us-east-2", "us-west-1", "us-west-2",
        "ca-central-1", "eu-west-1", "eu-west-2", "eu-west-3",
        "eu-central-1", "eu-north-1", "eu-south-1",
        "me-south-1", "me-central-1",
        "af-south-1",
        "ap-east-1", "ap-south-1", "ap-south-2",
        "ap-southeast-1", "ap-southeast-2", "ap-southeast-3",
        "ap-northeast-1", "ap-northeast-3",
        "sa-east-1"
      ]
    }
  }
}

# 3. 차단 정책 생성
resource "aws_iam_policy" "deny_other_regions_policy" {
  name        = "DenyAccessToOtherRegions"
  description = "Deny all AWS regions except ap-northeast-2 and global"
  policy      = data.aws_iam_policy_document.deny_other_regions.json
}

# 4. 정책 연결: AdministratorAccess
resource "aws_iam_user_policy_attachment" "attach_admin" {
  for_each = toset(local.usernames)

  user       = aws_iam_user.users[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 5. 정책 연결: Deny 외부 리전
resource "aws_iam_user_policy_attachment" "attach_deny_regions" {
  for_each = toset(local.usernames)

  user       = aws_iam_user.users[each.key].name
  policy_arn = aws_iam_policy.deny_other_regions_policy.arn
}

# 6. 정책 연결: 비밀번호 변경 허용
resource "aws_iam_user_policy_attachment" "attach_change_password" {
  for_each = toset(local.usernames)

  user       = aws_iam_user.users[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

# 7. 비밀번호 정책
resource "aws_iam_account_password_policy" "strict_policy" {
  minimum_password_length         = 10
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                 = true
  require_symbols                 = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
  hard_expiry                    = false
}

# 8. 로그인 프로필 (콘솔 로그인용 임시 비밀번호)
resource "aws_iam_user_login_profile" "login" {
  for_each = toset(local.usernames)

  user                    = aws_iam_user.users[each.key].name
  password_length         = 15
  password_reset_required = true
}

# 9. 액세스 키 발급
resource "aws_iam_access_key" "access_keys" {
  for_each = toset(local.usernames)
  user     = aws_iam_user.users[each.key].name
}

# 10. credentials 파일 저장
resource "local_file" "credentials" {
  for_each = aws_iam_access_key.access_keys

  filename = "${path.module}/credentials/${each.key}.txt"
  content  = <<-EOT
    IAM Username:          ${each.key}

    AWS Management Console Login:
    https://signin.aws.amazon.com/console
    Temporary Password:    ${aws_iam_user_login_profile.login[each.key].password}

    Programmatic Access (CLI / SDK):
    AWS Access Key ID:     ${each.value.id}
    AWS Secret Access Key: ${each.value.secret}
    암호 생성 시 10자 이상, 대문자, 소문자, 숫자, 특수문자를 포함해야 합니다.
  EOT

  file_permission      = "0600"
  directory_permission = "0700"
  depends_on = [
    aws_iam_user_login_profile.login,
    aws_iam_user_policy_attachment.attach_admin,
    aws_iam_user_policy_attachment.attach_deny_regions,
    aws_iam_user_policy_attachment.attach_change_password
  ]
}