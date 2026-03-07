output "api_url" {
  value = aws_api_gateway_stage.beta.invoke_url
}

output "api_gateway_arn" {
  value = aws_api_gateway_rest_api.MyDemoAPI.execution_arn
}