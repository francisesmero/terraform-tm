data "aws_secretsmanager_secret_version" "tm-db-secret" {
    secret_id = "arn:aws:secretsmanager:ap-southeast-1:561712037441:secret:tm-db-secret-xy2eb8"
}

provider "aws" {
  region    = "ap-southeast-1"
}

