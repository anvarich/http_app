provider "aws" {
  region = "eu-west-1"
}

variable "number_of_instances" {
  description = "Number of instances to create and attach to ELB"
  default     = 1
}

##############################################################
# Data sources to get VPC, subnets and security group details
##############################################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_security_group" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
  name   = "default"
}

######
# ELB
######
module "elb_http" {
  source = "terraform-aws-modules/elb/aws"

  name = "elb-example"

  subnets         = ["subnet-12345678", "subnet-87654321"]
  security_groups = ["sg-12345678"]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:80/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

  access_logs = [
    {
      bucket = "my-access-logs-bucket"
    },
  ]

  // ELB attachments
  number_of_instances = 2
  instances           = "${aws_instance.web.*.id}"
  
  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}
### CLOUD init

data "template_file" "script" {
  template = "${file("${path.module}/init.tpl")}"

  
}
data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  # Setup hello world script to be called by the cloud-config
  part {
    filename     = "init.cfg"
    content_type = "text/part-handler"
    content      = "${data.template_file.script.rendered}"
  }

}

################
# EC2 instances
################
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

resource "aws_instance" "web" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  count = 2

  tags {
    Name = "HelloWorld"
  }
}