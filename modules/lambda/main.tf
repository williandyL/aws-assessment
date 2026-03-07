terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


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
#Iam
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "greet" {
  name               = "lambda_execution_role-greet-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "LambdaDynamoDBAccess-${var.region}"
  description = "Allows Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        # Resource = "arn:aws:dynamodb:us-east-1:863435570010:table/YourTableName" 
        Resource = var.dynamodb_arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.greet.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}


#api-gateway

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
  integration_http_method = "POST"
  uri                     = aws_lambda_function.greeter.invoke_arn

  depends_on = [aws_api_gateway_method.protected_method, aws_lambda_function.greeter]
}


#dispatch
#iam

resource "aws_iam_role" "dispatch" {
  name               = "lambda_execution_role-dispatch-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_dispatch.json
}

data "aws_iam_policy_document" "assume_role_dispatch" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# 1. Define the permissions the Lambda needs
data "aws_iam_policy_document" "lambda_ecs_trigger_policy" {
  # Power 1: Run the Task
  statement {
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [var.task_definition]
  }

  # Power 2: Hand over the keys (PassRole)
  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]

    # You MUST include the ARNs of the ECS Task Role and Execution Role here
    resources = [
      aws_iam_role.ecr_task_execution_role.arn,
      aws_iam_role.ecr_task_role.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}



resource "aws_iam_policy" "lambda_ecs_exec" {
  name   = "LambdaToECSExecutionPolicy-${var.region}"
  policy = data.aws_iam_policy_document.lambda_ecs_trigger_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_ecs_trigger" {
  role       = aws_iam_role.dispatch.name
  policy_arn = aws_iam_policy.lambda_ecs_exec.arn
}

#ecr pass role

#execution
resource "aws_iam_role_policy_attachment" "attach_ecs_execution_trigger" {
  role       = aws_iam_role.ecr_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_policy.arn
}

resource "aws_iam_policy" "ecs_execution_policy" {
  policy = data.aws_iam_policy_document.ecr_execution_role.json
}


resource "aws_iam_role" "ecr_task_execution_role" {
  name               = "ecr-task-execution-role-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.ecr_assume_execution_role.json
}

data "aws_iam_policy_document" "ecr_assume_execution_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ecr_execution_role" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

#task
resource "aws_iam_role_policy_attachment" "attach_ecs_task_trigger" {
  role       = aws_iam_role.ecr_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

resource "aws_iam_policy" "ecs_task_policy" {
  policy = data.aws_iam_policy_document.ecr_task_role.json
}


resource "aws_iam_role" "ecr_task_role" {
  name               = "ecr-task-role-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.ecr_assume_task_role.json
}

data "aws_iam_policy_document" "ecr_assume_task_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ecr_task_role" {
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]

    resources = ["arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"]
  }
}



#api-gateway
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
  integration_http_method = "POST"
  uri                     = aws_lambda_function.dispatch.invoke_arn

  depends_on = [aws_api_gateway_method.dispatcher, aws_lambda_function.dispatch]
}


resource "aws_api_gateway_deployment" "myDeployment" {
  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.greet,
      aws_api_gateway_method.protected_method,
      aws_api_gateway_integration.greeter,
      aws_api_gateway_authorizer.cognito_auth
    ]))
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


//Lambda

# Package the Lambda function code
data "archive_file" "greeter" {
  type        = "zip"
  source_file = "${path.module}/greeter/index.mjs"
  output_path = "${path.module}/greeter/function.zip"
}

data "archive_file" "dispatcher" {
  type        = "zip"
  source_file = "${path.module}/dispatcher/index.mjs"
  output_path = "${path.module}/dispatcher/function.zip"
}

# Lambda function
resource "aws_lambda_function" "greeter" {
  filename      = data.archive_file.greeter.output_path
  function_name = "greeter"
  role          = aws_iam_role.greet.arn
  handler       = "index.handler"

  runtime = "nodejs20.x"

  environment {
    variables = {
      ENVIRONMENT = "production"
      LOG_LEVEL   = "info"
    }
  }

  tags = {
    Environment = "production"
    Application = "example"
  }
}

resource "aws_lambda_permission" "apigw_lambda-dispatch" {
  statement_id  = "AllowExecutionFromAPIGatewayDispatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatch.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion allows any stage and any method to call this lambda
  source_arn = "${aws_api_gateway_rest_api.MyDemoAPI.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_lambda-greet" {
  statement_id  = "AllowExecutionFromAPIGatewayGreet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion allows any stage and any method to call this lambda
  source_arn = "${aws_api_gateway_rest_api.MyDemoAPI.execution_arn}/*/*"
}

resource "aws_lambda_function" "dispatch" {
  filename      = data.archive_file.dispatcher.output_path
  function_name = "dispatch"
  role          = aws_iam_role.dispatch.arn
  handler       = "index.handler"

  runtime = "nodejs20.x"


  environment {
    variables = {
      SUBNET = var.ecs_subnet,
      SG     = var.ecs_sg
    }
  }

  tags = {
    Environment = "production"
    Application = "example"
  }
}