variable "instance_count" {}

provider "aws"{
  region = "us-east-2"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags {
    Name = "TempusChallengeVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "TempusPublicSubnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"

  tags {
    Name = "TempusPrivateSubnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "TempusIGW"
  }
}

resource "aws_eip" "nat" {
  vpc = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"

  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_route_table" "custom_route_table" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "TempusCustomRouteTable"
  }
}

resource "aws_route_table" "main_route_table" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  }

  tags {
    Name = "TempusMainRouteTable"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_route_table_association" "public_subnet_association" {
    subnet_id = "${aws_subnet.public_subnet.id}"
    route_table_id = "${aws_route_table.custom_route_table.id}"
}

resource "aws_route_table_association" "private_subnet_association" {
    subnet_id = "${aws_subnet.private_subnet.id}"
    route_table_id = "${aws_route_table.main_route_table.id}"
}


resource "aws_instance" "web" {
  count = "${var.instance_count}"
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private_subnet.id}"
  user_data = <<-EOF
              #!/bin/bash
              set -x
              echo "Installing dependencies for Docker"
              apt-get update
              apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
              echo "Installing dependencies for adding repository"
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              echo "Adding the repository"
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              echo "Install Docker"
              apt-get update
              apt-get install -y docker-ce
              echo "Run the container"
              docker run hello-world
              EOF
  tags {
    Name = "HelloWorld"
  }
  depends_on = ["aws_route_table_association.public_subnet_association",
                "aws_route_table_association.private_subnet_association"]
}
