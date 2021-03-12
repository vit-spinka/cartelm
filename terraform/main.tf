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


resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_dynamodb_and_logging"
  path        = "/"
  description = "IAM policy to access our DynamoDB table; also allow logging"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
			"Effect": "Allow",
			"Action": [
				"dynamodb:GetItem",
				"dynamodb:Query",
				"dynamodb:Scan",
				"dynamodb:PutItem",
				"dynamodb:UpdateItem",
				"dynamodb:DeleteItem"
			],
			"Resource": "arn:aws:dynamodb:${var.region}:*:table/${aws_dynamodb_table.cartelm_table.name}"
		},
		{
			"Effect": "Allow",
			"Action": [
				"logs:CreateLogStream",
				"logs:PutLogEvents"
			],
			"Resource": "arn:aws:logs:${var.region}:*:*"
		},
		{
			"Effect": "Allow",
			"Action": "logs:CreateLogGroup",
			"Resource": "*"
		},
		{
			"Effect": "Allow",
			"Action": "ses:SendRawEmail",
			"Resource": "arn:aws:ses:us-east-1:*:*"
		}
	]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "list_all_lambda" {
  filename      = "../rust/list_all.zip"
  function_name = "cartelm_list_all"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.handler" # this is a required parameter, but not used?

  source_code_hash = filebase64sha256("../rust/list_all.zip")

  runtime = "provided.al2"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.cartelm_table.name
    }
  }
}

resource "aws_lambda_function" "get_lambda" {
  filename      = "../rust/get.zip"
  function_name = "cartelm_get"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.handler" # this is a required parameter, but not used?

  source_code_hash = filebase64sha256("../rust/get.zip")

  runtime = "provided.al2"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.cartelm_table.name
    }
  }
}

resource "aws_lambda_function" "update_lambda" {
  filename      = "../rust/update.zip"
  function_name = "cartelm_update"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.handler" # this is a required parameter, but not used?

  source_code_hash = filebase64sha256("../rust/update.zip")

  runtime = "provided.al2"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.cartelm_table.name
    }
  }
}

resource "aws_lambda_function" "delete_lambda" {
  filename      = "../rust/delete.zip"
  function_name = "cartelm_delete"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.handler" # this is a required parameter, but not used?

  source_code_hash = filebase64sha256("../rust/delete.zip")

  runtime = "provided.al2"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.cartelm_table.name
    }
  }
}

resource "aws_lambda_function" "create_lambda" {
  filename      = "../rust/create.zip"
  function_name = "cartelm_create"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.handler" # this is a required parameter, but not used?

  source_code_hash = filebase64sha256("../rust/create.zip")

  runtime = "provided.al2"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.cartelm_table.name
    }
  }
}

resource "aws_api_gateway_rest_api" "cartelm_api_gateway" {
  name        = "CartElm gateway"
  description = "REST API for CartElm (admin)"
}

resource "aws_api_gateway_resource" "subscriptions" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.cartelm_api_gateway.root_resource_id
  path_part   = "subscription"
}

resource "aws_api_gateway_resource" "subscription" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  parent_id   = aws_api_gateway_resource.subscriptions.id
  path_part   = "{subscriptionId}"
}

resource "aws_api_gateway_method" "list_all" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscriptions.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_all_lambda" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_method.list_all.resource_id
  http_method = aws_api_gateway_method.list_all.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_all_lambda.invoke_arn
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscription.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.subscriptionId" = true
  }
}

resource "aws_api_gateway_integration" "get_lambda" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_method.get.resource_id
  http_method = aws_api_gateway_method.get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_lambda.invoke_arn
}

resource "aws_api_gateway_method" "delete" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscription.id
  http_method   = "DELETE"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.subscriptionId" = true
  }
}

resource "aws_api_gateway_integration" "delete_lambda" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_method.delete.resource_id
  http_method = aws_api_gateway_method.delete.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_lambda.invoke_arn
}

# update
resource "aws_api_gateway_method" "update" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscription.id
  http_method   = "PUT"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.subscriptionId" = true
  }
}

resource "aws_api_gateway_integration" "update_lambda" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_method.update.resource_id
  http_method = aws_api_gateway_method.update.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_lambda.invoke_arn
}

# create
resource "aws_api_gateway_method" "create" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscriptions.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_lambda" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_method.create.resource_id
  http_method = aws_api_gateway_method.create.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  depends_on = [
    aws_api_gateway_integration.list_all_lambda,
    aws_api_gateway_integration.get_lambda,
    aws_api_gateway_integration.update_lambda,
    aws_api_gateway_integration.delete_lambda,
    aws_api_gateway_integration.create_lambda,
    aws_api_gateway_integration.options_mock,
    aws_api_gateway_integration.options_mock_one
  ]

  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  stage_name  = "test"
  # stage_description = timestamp() # Enable to force redeploy on every run (use when editing the API)
}

resource "aws_lambda_permission" "list_all" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_all_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.cartelm_api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.cartelm_api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "update" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.cartelm_api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.cartelm_api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "create" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.cartelm_api_gateway.execution_arn}/*/*"
}

resource "aws_dynamodb_table" "cartelm_table" {
  name         = "CartElmSubscriptions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "subscriptionId"

  attribute {
    name = "subscriptionId"
    type = "S"
  }

  tags = {
    Environment = var.tag_envname
  }
}



resource "aws_lambda_function" "scrape_dilbert_lambda" {
  filename      = "../rust/scrape_dilbert.zip"
  function_name = "cartelm_scrape_dilbert"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "hello.handler" # this is a required parameter, but not used?

  source_code_hash = filebase64sha256("../rust/scrape_dilbert.zip")

  runtime = "provided.al2"

  timeout = 60

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.cartelm_table.name
    }
  }
}


resource "aws_cloudwatch_event_rule" "utc20" {
  name                = "utc20"
  description         = "Every day at 20:00 UTC"
  schedule_expression = "cron(0 20 * * ? *)"
}

resource "aws_cloudwatch_event_target" "run_dilbert_daily" {
  rule      = aws_cloudwatch_event_rule.utc20.name
  target_id = "dilbert_daily"
  arn       = aws_lambda_function.scrape_dilbert_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scrape_dilbert_lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.utc20.arn
}


#CORS
# module "cors" {
#   source  = "squidfunk/api-gateway-enable-cors/aws"
#   version = "0.3.1"

#   api_id          = aws_api_gateway_rest_api.cartelm_api_gateway.id
#   api_resource_id = aws_api_gateway_resource.subscription.id
#   #  aws_api_gateway_rest_api.cartelm_api_gateway.root_resource_id

# }


# module "apigateway_with_cors" {
#   source  = "alparius/apigateway-with-cors/aws"
#   version = "0.3.1"

#   lambda_function_name = aws_lambda_function.list_all_lambda.function_name
#   lambda_invoke_arn    = aws_lambda_function.list_all_lambda.invoke_arn
# }


### /subscriptions

resource "aws_api_gateway_method" "method_options" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscriptions.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_mock" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_resource.subscriptions.id
  http_method = aws_api_gateway_method.method_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

resource "aws_api_gateway_integration_response" "response_options" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_resource.subscriptions.id
  http_method = aws_api_gateway_method.method_options.http_method
  status_code = 200

  # response_parameters = local.integration_response_parameters
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
  }
  depends_on = [
    aws_api_gateway_integration.options_mock,
    aws_api_gateway_method_response.method_options_response,
  ]
}

# aws_api_gateway_method_response._
resource "aws_api_gateway_method_response" "method_options_response" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_resource.subscriptions.id
  http_method = aws_api_gateway_method.method_options.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [
    aws_api_gateway_method.method_options,
  ]
}


### /subscriptions/id

resource "aws_api_gateway_method" "method_options_one" {
  rest_api_id   = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id   = aws_api_gateway_resource.subscription.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_mock_one" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_resource.subscription.id
  http_method = aws_api_gateway_method.method_options_one.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

resource "aws_api_gateway_integration_response" "response_options_one" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_resource.subscription.id
  http_method = aws_api_gateway_method.method_options_one.http_method
  status_code = 200

  # response_parameters = local.integration_response_parameters
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Requested-With'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,DELETE,PUT'"
  }
  depends_on = [
    aws_api_gateway_integration.options_mock_one,
    aws_api_gateway_method_response.method_options_response_one,
  ]
}

# aws_api_gateway_method_response._
resource "aws_api_gateway_method_response" "method_options_response_one" {
  rest_api_id = aws_api_gateway_rest_api.cartelm_api_gateway.id
  resource_id = aws_api_gateway_resource.subscription.id
  http_method = aws_api_gateway_method.method_options_one.http_method
  status_code = 200

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [
    aws_api_gateway_method.method_options_one,
  ]
}
