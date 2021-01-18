variable "region" { default = "us-west-2" }
variable "tag_envname" { default = "dev" }
variable "tag_user_name" { default = "spinka" }

terraform {
  backend "s3" {
    bucket         = "spinka-terraform-backend-states"
    key            = "cartelm"
    dynamodb_table = "terraform-backend-locking-cartelm"
    region         = "us-west-2"
  }
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "s3_hosting" {
  bucket = "cartelm-hosting"
  acl    = "public-read"
  ## CORS?

  tags = {
    Name        = "CartElm static hosting"
    Environment = var.tag_envname
    User        = var.tag_user_name
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "list_all_lambda" {
  filename      = "../rust/list_all.zip"
  function_name = "cartelm_list_all"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.handler" # this is a required parameter, but not used?

  source_code_hash = filebase64sha256("../rust/list_all.zip")

  runtime = "provided.al2"

  #   environment {
  #     variables = {
  #       foo = "bar"
  #     }
  #   }
}


resource "aws_api_gateway_rest_api" "cartelm_api_gateway" {
  name        = "CartElm gateway"
  description = "REST API for CartElm (admin)"
}

resource "aws_api_gateway_resource" "subscription" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.cartelm_api_gateway.root_resource_id
  path_part   = "subscription"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscription.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_all_lambda" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_all_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  depends_on = [
    aws_api_gateway_integration.list_all_lambda,
    #  aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  stage_name  = "test"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_all_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.cartelm_api_gateway.execution_arn}/*/*"
}
