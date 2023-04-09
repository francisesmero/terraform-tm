resource "aws_vpc" "tm_vpc" {
  cidr_block = "172.30.0.0/21"

  tags = {
    Name = "tm-vpc"
  }
}

resource "aws_subnet" "public_subnet_bastion" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-bastion"
  }
}


resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "private-subnet-1-db"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.2.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "private-subnet-2-db"
  }
}

resource "aws_subnet" "private_subnet_etl" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.3.0/24"

  tags = {
    Name = "private-subnet-etl"
  }
}

resource "aws_subnet" "public_subnet_flask" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.4.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name     = "public-subnet-flask"
  }
}

# security groups 

resource "aws_security_group" "bastion_security_group" {
  name_prefix     = "bastion-"
  vpc_id          = aws_vpc.tm_vpc.id
}

resource "aws_security_group" "flask_security_group" {
  name_prefix     = "flask-"
  vpc_id          = aws_vpc.tm_vpc.id
}

resource "aws_security_group" "etl_rds_security_group" {
  name_prefix     = "etl_rds-"
  vpc_id          = aws_vpc.tm_vpc.id
}



# bastion security group rules

resource "aws_security_group_rule" "bastion-ingress-rule-1" {
  type                     = "ingress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.bastion_security_group.id
}

resource "aws_security_group_rule" "bastion-ingress-rule-2" {
  type                     = "ingress"
  from_port                = "3306"
  to_port                  = "3306"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_security_group.id
  source_security_group_id = aws_security_group.etl_rds_security_group.id
}

resource "aws_security_group_rule" "bastion-egress-rule-1" {
  type                     = "egress"
  from_port                = "8080"
  to_port                  = "8080"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_security_group.id
  source_security_group_id = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "bastion-egress-rule-2" {
  type                     = "egress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_security_group.id
  source_security_group_id = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "bastion-egress-rule-3" {
  type                     = "egress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_security_group.id
  source_security_group_id = aws_security_group.etl_rds_security_group.id
}



# flask app security group rules

resource "aws_security_group_rule" "flask-ingress-rule-1" {
  type                     = "ingress"
  from_port                = "80"
  to_port                  = "80"
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "flask-ingress-rule-2" {
  type                     = "ingress"
  from_port                = "443"
  to_port                  = "443"
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "flask-ingress-rule-3" {
  type                     = "ingress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_security_group.id
  security_group_id        = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "flask-egress-rule-1" {
  type                     = "egress"
  from_port                = "3306"
  to_port                  = "3306"
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.etl_rds_security_group.id
  security_group_id        = aws_security_group.flask_security_group.id
}

# rds-etl security group rules

resource "aws_security_group_rule" "etl-rds-ingress-rule-1" {
  type                     = "ingress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.bastion_security_group.id
}

resource "aws_security_group_rule" "etl-rds-ingress-rule-2" {
  type                     = "ingress"
  from_port                = "3306"
  to_port                  = "3306"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "etl-rds-egress-rule-1" {
  type                     = "egress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.bastion_security_group.id
}

resource "aws_security_group_rule" "etl-rds-egress-rule-2" {
  type                     = "egress"
  from_port                = "3306"
  to_port                  = "3306"
  protocol                 = "tcp"
  security_group_id        = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.flask_security_group.id
}


resource "aws_db_subnet_group" "multi_az_subnets" {
  name        = "multi-az-db-subnet-group"
  subnet_ids  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags        = {
    Name = "multi-az-db-subnet-group"
  }
}

resource "aws_db_instance" "tm-checkin-db" {
  allocated_storage      = 10
  engine_version         = "5.7"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  db_name                = "tmcheckindb"
  identifier             = "tm-checkin-db"
  skip_final_snapshot    = false
  vpc_security_group_ids = [aws_security_group.etl_rds_security_group.id]
  username               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["username"]
  password               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.multi_az_subnets.name
}




resource "aws_instance" "ec2-bastion" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_bastion.id
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]

  tags = {
    Name = "ec2_bastion_host"
  }
}

resource "aws_instance" "ec2-flask" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_flask.id
  vpc_security_group_ids = [aws_security_group.flask_security_group.id]

  tags = {
    Name = "ec2_flask_app"
  }
}




resource "aws_s3_bucket" "tm_s3_bucket" {
  bucket = "tm-csv-bucket"
}

resource "aws_s3_bucket_acl" "tm_s3_bucket_acl" {
  bucket = aws_s3_bucket.tm_s3_bucket.id

  acl = "private"
}

resource "aws_s3_object" "cleaned_data" {
  bucket = aws_s3_bucket.tm_s3_bucket.id
  key    = "cleaned_data/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "raw_data" {
  bucket = aws_s3_bucket.tm_s3_bucket.bucket
  key    = "raw_data/"
  content_type = "application/x-directory"
}
