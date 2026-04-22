output "parameter_name" { value = aws_ssm_parameter.secret.name }
output "read_policy_arn" { value = aws_iam_policy.read_policy.arn }