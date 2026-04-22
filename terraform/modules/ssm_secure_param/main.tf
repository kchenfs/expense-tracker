# 1. Fetch the Default AWS KMS key for SSM
data "aws_kms_alias" "ssm_key" {
  name = "alias/aws/ssm"
}

# 2. Create the Parameter
resource "aws_ssm_parameter" "secret" {
  name  = var.parameter_name
  type  = "SecureString"
  value = var.secret_value
}

# 3. Generate the IAM Policy to read it
resource "aws_iam_policy" "read_policy" {
  name   = "${var.name_prefix}-ssm-read-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = aws_ssm_parameter.secret.arn
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = data.aws_kms_alias.ssm_key.target_key_arn
      }
    ]
  })
}