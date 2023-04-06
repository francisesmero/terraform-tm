resource "aws_vpc" "tm-vpc" {
  cidr_block       = "172.30.0.0/21"
  instance_tenancy = "default"

  tags = {
    Name = "tm_vpc"
  }
}


resource "aws_key_pair" "my_keypair" {
  key_name   = "my-keypair"
  public_key = file("~/.ssh/id_rsa.pub")
}



resource "aws_subnet" "public-s-1" {
  vpc_id       = aws_vpc.tm-vpc.id
  cidr_block   = "172.30.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_s1"
  }
}

resource "aws_subnet" "private-s-1" {
  vpc_id     = aws_vpc.tm-vpc.id
  cidr_block = "172.30.1.0/24"

  tags = {
    Name = "private_s1"
  }
}

resource "aws_subnet" "private-s-2" {
  vpc_id     = aws_vpc.tm-vpc.id
  cidr_block = "172.30.2.0/24"

  tags = {
    Name = "private_s2"
  }
}

resource "aws_subnet" "private-s-3" {
  vpc_id     = aws_vpc.tm-vpc.id
  cidr_block = "172.30.3.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "private_s3"
  }
}

resource "aws_subnet" "private-s-4" {
  vpc_id     = aws_vpc.tm-vpc.id
  cidr_block = "172.30.4.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "private_s4"
  }
}



resource "aws_internet_gateway" "tm-igw" {
  vpc_id = aws_vpc.tm-vpc.id

  tags = {
    Name = "tm_igw"
  }
}

resource "aws_route_table" "tm-public-rt" {
  vpc_id = aws_vpc.tm-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tm-igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-s-1.id
  route_table_id = aws_route_table.tm-public-rt.id
}


resource "aws_instance" "ec2-etl" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private-s-1.id

  tags = {
    Name = "ec2_etl"
  }
}

resource "aws_instance" "ec2-be" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private-s-2.id

  tags = {
    Name = "ec2_be"
  }
}



resource "aws_instance" "ec2-bastion" {
  ami           = "ami-0ce792959cf41c394"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public-s-1.id
  key_name = aws_key_pair.my_keypair.key_name

  tags = {
    Name = "ec2_bastion"
  }
}


resource "aws_db_subnet_group" "tm-subnet-group" {
  name        = "tm-subnet-group"
  description = "DB subnet group"

  subnet_ids = [
    aws_subnet.private-s-3.id,
    aws_subnet.private-s-4.id
  ]
}

resource "aws_security_group" "tm-checkin-db-sg" {
  name_prefix = "tm-checkin-db-sg"
  vpc_id      = aws_vpc.tm-vpc.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tm-checkin-db-sg"
  }
}


resource "aws_security_group" "bastion-sg" {
  name_prefix = "bastion-sg"
  vpc_id      = aws_vpc.tm-vpc.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tm-checkin-db-sg"
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
  vpc_security_group_ids = [aws_security_group.tm-checkin-db-sg.id]
  username               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["username"]
  password               = jsondecode(data.aws_secretsmanager_secret_version.tm-db-secret.secret_string)["password"]
  db_subnet_group_name   = aws_db_subnet_group.tm-subnet-group.name
}



resource "aws_s3_bucket" "tm_s3_bucket" {
  bucket = "tm-csv-bucket"
}

resource "aws_s3_bucket_acl" "tm_s3_bucket_acl" {
  bucket = aws_s3_bucket.tm_s3_bucket.id

  acl = "private"
}

resource "aws_s3_bucket_object" "cleaned_data" {
  bucket = aws_s3_bucket.tm_s3_bucket.id
  key    = "cleaned_data/"
  content_type = "application/x-directory"
}

resource "aws_s3_bucket_object" "raw_data" {
  bucket = aws_s3_bucket.tm_s3_bucket.bucket
  key    = "raw_data/"
  content_type = "application/x-directory"
}