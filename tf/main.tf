// AWS access
provider "aws" {
  region = "us-east-2"
}

variable "gitid" {
  type = string
}

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "alnn-api-lambda-bucket"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "lambda_code_object" {
  bucket        = aws_s3_bucket.lambda_code_bucket.id
  key           = "function_${var.gitid}.zip"
  source        = "../function.zip"
  cache_control = "no-cache"
}

resource "aws_iam_role" "lambda_code_iam" {
  name               = "alnn_api_lambda_iam"
  assume_role_policy = <<EOF
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
  name   = "alnn-api-lambda-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": [
        " arn:aws:s3:::alnn-main-bucket-8nyb87yn8"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy_atch" {
  role       = aws_iam_role.lambda_code_iam.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


resource "aws_lambda_permission" "lambda_alb_permission" {
  statement_id  = "AllowExecutionFromAlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_func.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.alb_tg.arn
}

resource "aws_lambda_function" "lambda_func" {
  function_name    = "alnn-api-lambda-func"
  role             = aws_iam_role.lambda_code_iam.arn
  source_code_hash = base64sha256(filebase64("../function.zip"))
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  s3_bucket        = aws_s3_bucket.lambda_code_bucket.id
  s3_key           = "function_${var.gitid}.zip"
  depends_on       = [aws_s3_bucket.lambda_code_bucket, aws_s3_bucket_object.lambda_code_object]
}

resource "aws_security_group" "aws_sg" {
  description = "my ip"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Project = "alnn-api"
  }
}

resource "aws_lb" "alb" {
  name               = "alnn-api-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.aws_sg.id]
  subnets            = ["subnet-2a727b42", "subnet-79713603"]
}

resource "aws_lb_target_group" "alb_tg" {
  name        = "alnn-api-alb-tg"
  target_type = "lambda"
  protocol    = "HTTP"
  port        = 80
}

resource "aws_lb_target_group_attachment" "alb_tg_atch" {
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_lambda_function.lambda_func.arn
  depends_on       = [aws_lambda_permission.lambda_alb_permission]
}

resource "aws_lb_listener" "alb_listener_lambda" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}