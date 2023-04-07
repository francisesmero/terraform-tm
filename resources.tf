resource "aws_vpc" "tm_vpc" {
  cidr_block = "172.30.0.0/21"

  tags = {
    Name = "tm-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
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

resource "aws_subnet" "private_subnet_3" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.3.0/24"

  tags = {
    Name = "private-subnet-3-etl"
  }
}

resource "aws_subnet" "private_subnet_4" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.4.0/24"

  tags = {
    Name = "private-subnet-3-be"
  }
}


resource "aws_security_group" "bastion_security_group" {
  name_prefix = "bastion-"
  vpc_id      = aws_vpc.tm_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-security-group"
  }
}

resource "aws_security_group" "etl_security_group" {
  name_prefix = "etl-"
  vpc_id      = aws_vpc.tm_vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups = [aws_security_group.bastion_security_group.id]
  }

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    # security_groups = [aws_security_group.backend_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "etl-security-group"
  }
}

resource "aws_security_group" "backend_security_group" {
  name_prefix = "backend-"
  vpc_id      = aws_vpc.tm_vpc.id

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups = [aws_security_group.etl_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-security-group"
  }
}

resource "aws_security_group" "rds_security_group" {
  name_prefix = "rds-"
  description = "Security group for RDS instance"
  vpc_id = aws_vpc.tm_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-security-group"
  }
}

# data "aws_subnets" "default" {
#   filter {
#       name   = tm_vpc.id
#       values = [var.vpc_id]
#   }
# }


resource "aws_db_subnet_group" "multi_az_subnets" {
  name        = "multi-az-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
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
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  username               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["username"]
  password               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.multi_az_subnets.name
}

resource "aws_instance" "ec2-backend" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.backend_security_group.id]

  tags = {
    Name = "ec2_backend"
  }
}

resource "aws_instance" "ec2-etl" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.etl_security_group.id]

  tags = {
    Name = "ec2_etl_pipeline"
  }
}

resource "aws_instance" "ec2-bastion" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]

  tags = {
    Name = "ec2_bastion_host"
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
