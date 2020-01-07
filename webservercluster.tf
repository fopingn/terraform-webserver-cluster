provider "aws" {
  region  = var.region
  version = "~>2.0"
  access_key = "abc123"
  secret_key = "abc123"
}

# vpc module
module "vpc_webcluster" {
  source        = "git::https://git@github.com/fopingn/terraform-aws-vpc-basic.git?ref=v0.4"
  name          = "web"
  cidr          = "10.0.0.0/16"
  public_subnet = "10.0.1.0/24"
}
# terraform s3 remote state
terraform {
  backend "s3" {
# bucket name has to be replace by your own
    bucket = "name of your s3 bucket for terraform state file"
    key    = "terraform.tfstate"
    region = "region of the bucket fi=or the terraform state file"
  }
}

data "template_file" "index" {
  count    = length(var.instance_ips)
  template = file("files/index.html.tpl")

  vars = {
    hostname = "web-${format("%03d", count.index + 1)}"
  }
}

resource "aws_instance" "web" {
  #ami and instance_type can be change to match your own
  ami                         = "ami-04b9e92b5572fa0d1"
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  subnet_id                   = module.vpc_webcluster.public_subnet_id
  private_ip                  = var.instance_ips[count.index]
  associate_public_ip_address = true
  monitoring                  = true
  vpc_security_group_ids = [
    aws_security_group.web_clusterhost_sg.id,
  ]

  tags = {
    Name = "web-${format("%03d", count.index + 1)}"
  }

  count = length(var.instance_ips)

  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("path_of_private_key/name_key")
  }

  provisioner "file" {
    content     = element(data.template_file.index[*].rendered, count.index)
    destination = "/tmp/index.html"
  }

  provisioner "remote-exec" {
    script = "files/bootstrap_puppet.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/index.html /usr/share/nginx/html/index.html",
    ]
  }

}

resource "aws_elb" "web" {
  name            = "web-elb"
  subnets         = [module.vpc_webcluster.public_subnet_id]
  security_groups = [aws_security_group.web_inbound_sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances = aws_instance.web[*].id
}

resource "aws_security_group" "web_inbound_sg" {
  name        = "web_inbound"
  description = "Allow HTTP from Anywhere"
  vpc_id      = module.vpc_webcluster.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_clusterhost_sg" {
  name        = "web_host"
  description = "Allow SSH & HTTP to web hosts"
  vpc_id      = module.vpc_webcluster.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.vpc_webcluster.cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
