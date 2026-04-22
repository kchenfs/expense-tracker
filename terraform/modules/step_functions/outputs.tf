output "state_machine_arn" {
  value = aws_sfn_state_machine.sfn_state_machine.arn
}

output "state_machine_id" {
  value = aws_sfn_state_machine.sfn_state_machine.id
}

# Add this to terraform/modules/step_functions/outputs.tf
output "role_name" {
  value = aws_iam_role.sfn_role.name
}