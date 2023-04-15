resource "aws_vpc" "tm_vpc" {
  cidr_block = "172.30.0.0/21"

  tags = {
    Name = "tm-vpc"
  }
}

resource "aws_internet_gateway" "tm_internet_gateway" {
  vpc_id = aws_vpc.tm_vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_eip" "nat_gw" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.public_subnet_nat.id
}


# Create a route table for public subnet that contains the bastion host and Flask app
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tm_vpc.id

  # Add a route to the internet gateway for the public subnet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tm_internet_gateway.id
  }

  tags = {
    Name = "public"
  }
}

# Create route table for private subnet that contains the RDS instance and ETL pipeline
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tm_vpc.id

  # Add a route to NAT for private subnet
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private"
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

resource "aws_subnet" "public_subnet_nat" {
  vpc_id     = aws_vpc.tm_vpc.id
  cidr_block = "172.30.5.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-nat"
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

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet_bastion.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_flask" {
  subnet_id      = aws_subnet.public_subnet_flask.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_etl" {
  subnet_id      = aws_subnet.private_subnet_etl.id
  route_table_id = aws_route_table.private.id
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

resource "aws_security_group" "glue_security_group" {
  name_prefix     = "glue-"
  vpc_id          = aws_vpc.tm_vpc.id
}


# security group rules

# glue security group rules

resource "aws_security_group_rule" "glue_inbound"{
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.glue_security_group.id
}

resource "aws_security_group_rule" "glue_outbound"{
    type        = "egress"
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.glue_security_group.id
  }

# bastion security group rules

# Allow SSH access to bastion from your machine and internet
resource "aws_security_group_rule" "bastion_ssh_inbound" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["124.104.123.156/32", "0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_security_group.id
}

# Allow access from bastion to RDS
resource "aws_security_group_rule" "bastion_to_rds" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_security_group.id
}

# Allow incoming traffic from bastion to Flask
resource "aws_security_group_rule" "flask_inbound" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.flask_security_group.id
  source_security_group_id = aws_security_group.bastion_security_group.id
}

resource "aws_security_group_rule" "flask_ssh_inbound" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["124.104.123.156/32", "0.0.0.0/0"]
  security_group_id = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "flask_inbound_app" {
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.flask_security_group.id
}

resource "aws_security_group_rule" "flask_inbound_nginx" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.flask_security_group.id
}


resource "aws_security_group_rule" "flask_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.flask_security_group.id
}

# Allow incoming traffic to RDS from Flask
resource "aws_security_group_rule" "rds_inbound" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.flask_security_group.id
}

# Allow incoming traffic to RDS from glue
resource "aws_security_group_rule" "rds_inbound_glue" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.glue_security_group.id
}

# Allow outgoing traffic to glue from RDS
resource "aws_security_group_rule" "rds_outbound_glue" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.glue_security_group.id
}

resource "aws_security_group_rule" "rds_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.flask_security_group.id
  source_security_group_id = aws_security_group.etl_rds_security_group.id
}


# Allow incoming traffic to RDS from Flask
resource "aws_security_group_rule" "bastion_inbound" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.etl_rds_security_group.id
  source_security_group_id = aws_security_group.bastion_security_group.id
}


resource "aws_db_instance" "tm-checkin-db" {
  allocated_storage      = 10
  engine_version         = "5.7"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  db_name                = "tmcheckindb"
  identifier             = "tm-checkin-db"
  skip_final_snapshot    = false
  vpc_security_group_ids = [aws_security_group.etl_rds_security_group.id, aws_security_group.bastion_security_group.id]
  username               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["username"]
  password               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.multi_az_subnets.name
  multi_az               = true
}

resource "aws_db_subnet_group" "multi_az_subnets" {
  name        = "multi-az-db-subnet-group"
  subnet_ids  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags        = {
    Name = "multi-az-db-subnet-group"
  }
}

# generate key-pairs for bation and flask

resource "tls_private_key" "bastion_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "flask_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_key_pair" {
  key_name   = "bastion_key_pair"
  public_key = tls_private_key.bastion_private_key.public_key_openssh
}

resource "aws_key_pair" "flask_key_pair" {
  key_name   = "flask_key_pair"
  public_key = tls_private_key.flask_private_key.public_key_openssh
}

resource "local_file" "bastion-key" {
  content  = tls_private_key.bastion_private_key.private_key_pem
  filename = "bastion_key_pair.pem"
}

resource "local_file" "flask-key" {
  content  = tls_private_key.flask_private_key.private_key_pem
  filename = "flask_key_pair.pem"
}



resource "aws_instance" "ec2-bastion" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_bastion.id
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  key_name      = aws_key_pair.bastion_key_pair.key_name

  tags = {
    Name = "ec2_bastion_host"
  }
}

resource "aws_instance" "ec2-flask" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_flask.id
  vpc_security_group_ids = [aws_security_group.flask_security_group.id]
  key_name      = aws_key_pair.flask_key_pair.key_name

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
