terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  backend "s3" {
    bucket = "terraform-state-willy"
    key    = "state"
    region = "ap-southeast-3"
  }
  required_version = ">= 1.2"
}

# variable "test_user_password" {
#   description = "The password for the test Cognito user, passed from ENV. I am trying to output AWS geenrated password from terraform to github action but failed"
#   type        = string
#   sensitive   = true
# }

provider "aws" {
  alias  = "US"
  region = "us-east-1"
}

provider "aws" {
  alias  = "Ireland"
  region = "eu-west-1"
}


module "cognito" {
  source = "./modules/cognito"
  providers = {
    aws = aws.US
  }
}

output "cognito-region" {
  value = module.cognito.cognito_region
}

output "test_username" {
  value     = module.cognito.cognito_test_username
  sensitive = true
}

output "test_password" {
  value     = module.cognito.cognito_test_password
  sensitive = true
}

output "client_id" {
  value = module.cognito.cognito_client_id
}


module "iam" {
  source = "./modules/iam"
}

module "vpc-us" {
  source = "./modules/vpc"
  subnet = "12.0.1.0/24"
  vpc    = "12.0.0.0/16"
  providers = {
    aws = aws.US
  }
}

module "vpc-irland" {
  source = "./modules/vpc"
  subnet = "11.0.1.0/24"
  vpc    = "11.0.0.0/16"
  providers = {
    aws = aws.Ireland
  }
}

module "lambda-irland" {
  source       = "./modules/lambda"
  ecs_sg       = module.vpc-irland.sg
  ecs_subnet   = module.vpc-irland.subnet
  aws_cognito_user_pool_arn = module.cognito.aws_cognito_user_pool_arn
  dynamodb_arn = module.dynamodb.replica_arns_list[0]
  region = "Irland"
  task_definition = module.ecs-irland.task_definition
  providers = {
    aws = aws.Ireland
  }
}

module "lambda-us" {
  source       = "./modules/lambda"
  ecs_sg       = module.vpc-us.sg
  ecs_subnet   = module.vpc-us.subnet
  aws_cognito_user_pool_arn = module.cognito.aws_cognito_user_pool_arn
  dynamodb_arn = module.dynamodb.db_arn
  region = "US"
  task_definition = module.ecs-us.task_definition
  providers = {
    aws = aws.US
  }
}

output "api-gateway-irland-url" {
  value = module.lambda-irland.api_url
}

output "api-gateway-us-url" {
  value = module.lambda-us.api_url
}

# module "api-gateway-irland" {
#   source                                   = "./modules/api-gateway"
#   aws_cognito_user_pool_arn                = module.cognito.aws_cognito_user_pool_arn
#   greeter_response_streaming_invoke_arn    = module.lambda-irland.greeter_response_invoke_arn
#   dispatcher_response_streaming_invoke_arn = module.lambda-irland.dispatcher_response_invoke_arn
#   depends_on                               = [module.cognito, module.lambda-irland]
#   providers = {
#     aws = aws.Ireland
#   }
# }

# module "api-gateway-us" {
#   source                                   = "./modules/api-gateway"
#   aws_cognito_user_pool_arn                = module.cognito.aws_cognito_user_pool_arn
#   greeter_response_streaming_invoke_arn    = module.lambda-us.greeter_response_invoke_arn
#   dispatcher_response_streaming_invoke_arn = module.lambda-us.dispatcher_response_invoke_arn
#   depends_on                               = [module.cognito, module.lambda-us]
#   providers = {
#     aws = aws.US
#   }
# }


module "dynamodb" {
  source = "./modules/dynamodb"
  providers = {
    aws = aws.US
  }
}


module "ecs-us" {
  source         = "./modules/ecs"
  execution_role = module.lambda-us.execution_role
  task_role      = module.lambda-us.task_role
  providers = {
    aws = aws.US
  }
  depends_on = [module.iam]
}

module "ecs-irland" {
  source         = "./modules/ecs"
  execution_role = module.lambda-irland.execution_role
  task_role      = module.lambda-irland.task_role
  providers = {
    aws = aws.Ireland
  }
  depends_on = [module.iam]
}