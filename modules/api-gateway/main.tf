# resource "aws_api_gateway_rest_api" "my_api" {
#   body = jsonencode({
#     openapi = "3.0.1"
#     info = {
#       title   = "greet"
#       version = "1.0"
#     }
#     paths = {
#       "/greet" = {
#         get = {
#           x-amazon-apigateway-integration = {
#             httpMethod           = "GET"
#             payloadFormatVersion = "1.0"
#             type                 = "HTTP_PROXY"
#             uri                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
#           }
#         }
#       }
#     }
#   })

#   name = "example"

#   endpoint_configuration {
#     types = ["REGIONAL"]
#   }
# }

# resource "aws_api_gateway_deployment" "example" {
#   rest_api_id = aws_api_gateway_rest_api.my_api.id

#   triggers = {
#     redeployment = sha1(jsonencode(aws_api_gateway_rest_api.my_api.body))
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_api_gateway_stage" "example" {
#   deployment_id = aws_api_gateway_deployment.example.id
#   rest_api_id   = aws_api_gateway_rest_api.my_api.id
#   stage_name    = "example"
# }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_api_gateway_rest_api" "MyDemoAPI" {
  name        = "MyDemoAPI"
  description = "This is my API for demonstration purposes"
}

resource "aws_api_gateway_authorizer" "cognito_auth" {
  name          = "CognitoAuthorizer"
  rest_api_id   = aws_api_gateway_rest_api.MyDemoAPI.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.aws_cognito_user_pool_arn]
}


#greet
resource "aws_api_gateway_resource" "greet" {
  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id
  parent_id   = aws_api_gateway_rest_api.MyDemoAPI.root_resource_id
  path_part   = "greet"
}

resource "aws_api_gateway_method" "protected_method" {
  rest_api_id   = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id   = aws_api_gateway_resource.greet.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id

  depends_on = [aws_api_gateway_resource.greet]
}

resource "aws_api_gateway_integration" "greeter" {
  rest_api_id             = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id             = aws_api_gateway_resource.greet.id
  http_method             = aws_api_gateway_method.protected_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "GET"
  uri                     = var.greeter_response_streaming_invoke_arn

  depends_on = [aws_api_gateway_method.protected_method, var.greeter_response_streaming_invoke_arn]
}


#dispatch
resource "aws_api_gateway_resource" "dispatch" {
  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id
  parent_id   = aws_api_gateway_rest_api.MyDemoAPI.root_resource_id
  path_part   = "dispatch"
}

resource "aws_api_gateway_method" "dispatcher" {
  rest_api_id   = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id   = aws_api_gateway_resource.dispatch.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id

  depends_on = [aws_api_gateway_resource.dispatch]
}

resource "aws_api_gateway_integration" "dispatcher" {
  rest_api_id             = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id             = aws_api_gateway_resource.dispatch.id
  http_method             = aws_api_gateway_method.dispatcher.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "GET"
  uri                     = var.dispatcher_response_streaming_invoke_arn

  depends_on = [aws_api_gateway_method.dispatcher, var.dispatcher_response_streaming_invoke_arn]
}


resource "aws_api_gateway_deployment" "myDeployment" {
  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.MyDemoAPI.body))
  }

  depends_on = [aws_api_gateway_resource.greet, aws_api_gateway_integration.greeter, aws_api_gateway_resource.dispatch, aws_api_gateway_integration.dispatcher]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "beta" {
  deployment_id = aws_api_gateway_deployment.myDeployment.id
  rest_api_id   = aws_api_gateway_rest_api.MyDemoAPI.id
  stage_name    = "beta"
}
