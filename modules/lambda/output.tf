output "greeter_response_invoke_arn" {
  value = aws_lambda_function.greeter.invoke_arn
}

output "dispatcher_response_invoke_arn" {
  value = aws_lambda_function.dispatch.invoke_arn
}

output "api_url" {
  value = aws_api_gateway_stage.beta.invoke_url
}

output "api_gateway_arn" {
  value = aws_api_gateway_rest_api.MyDemoAPI.execution_arn
}

output "execution_role" {
  value = aws_iam_role.ecr_task_execution_role.arn
}

output "task_role" {
  value = aws_iam_role.ecr_task_role.arn
}