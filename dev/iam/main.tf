# 사용자 생성 후 계정을 전달하여 로그인 시도를 통해 비밀번호를 변경하도록 안내합니다.
# 이후 주석처리된 정책을 주석 해제 후 apply하여 서울 리전에서만 관리자 권한을 허용합니다.

locals {
  usernames = [for i in range(1, 11) : "ge-testuser${i}"] # 1부터 10까지의 유저 생성, 이름 및 range 값 조정 필요
}

# 1. IAM 사용자 생성
resource "aws_iam_user" "users" {
  for_each = toset(local.usernames)
  name     = each.key
}

# # 2. 서울 리전에서만 관리자 권한 허용 정책 문서
# data "aws_iam_policy_document" "seoul_only_admin" {
#   statement {
#     sid     = "AllowAllActionsInSeoul"
#     effect  = "Allow"
#     actions = ["*"]
#     resources = ["*"]
#     condition {
#       test     = "StringEquals"
#       variable = "aws:RequestedRegion"
#       values   = ["ap-northeast-2"]
#     }
#   }

#   statement {
#     sid     = "DenyAllActionsOutsideSeoul"
#     effect  = "Deny"
#     actions = ["*"]
#     resources = ["*"]
#     condition {
#       test     = "StringNotEquals"
#       variable = "aws:RequestedRegion"
#       values   = ["ap-northeast-2"]
#     }
#   }
# }

# # 3. 정책 생성
# resource "aws_iam_policy" "seoul_admin_restricted" {
#   name        = "AdminAccess-SeoulOnly"
#   description = "Admin access only in ap-northeast-2"
#   policy      = data.aws_iam_policy_document.seoul_only_admin.json
# }

# # 4. 서울 리전 제한 Admin 정책 연결
# resource "aws_iam_user_policy_attachment" "attach_seoul_admin" {
#   for_each = toset(local.usernames)

#   user       = aws_iam_user.users[each.key].name
#   policy_arn = aws_iam_policy.seoul_admin_restricted.arn
# }

# 5. IAMUserChangePassword 관리형 정책 연결
resource "aws_iam_user_policy_attachment" "attach_change_password" {
  for_each = toset(local.usernames)

  user       = aws_iam_user.users[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

# 6. 비밀번호 정책 적용
resource "aws_iam_account_password_policy" "strict_policy" {
  minimum_password_length         = 14
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                 = true
  require_symbols                 = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
  hard_expiry                    = false
}

# 7. IAM 로그인 프로필 (콘솔 로그인용 임시 비밀번호)
resource "aws_iam_user_login_profile" "login" {
  for_each = toset(local.usernames)

  user                    = aws_iam_user.users[each.key].name
  password_length         = 20
  password_reset_required = true
}

# 8. Access Key 발급
resource "aws_iam_access_key" "access_keys" {
  for_each = toset(local.usernames)
  user     = aws_iam_user.users[each.key].name
}

# 9. local_file 저장
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
    암호 생성시 10자 이상, 대문자, 소문자, 숫자, 특수문자를 포함해야 합니다.
  EOT

  file_permission      = "0600"
  directory_permission = "0700"
  depends_on = [
    aws_iam_user_login_profile.login,
    aws_iam_user_policy_attachment.attach_change_password,
    aws_iam_user_policy_attachment.attach_seoul_admin
  ]
}