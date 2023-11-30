module "iam_instance_profile" {
  source  = "terraform-in-action/iip/aws"
  actions = ["logs:*", "rds:*"] #A
}



data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

resource "aws_launch_template" "webserver" {
  name_prefix   = var.namespace
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = var.ssh_keypair
  user_data = "${file("userdata.sh")}"

  iam_instance_profile {
    name = module.iam_instance_profile.name
  }
  vpc_security_group_ids = [var.sg.websvr]

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_size = 50 
  }

  block_device_mappings {
    device_name = "/dev/sdf"  
    volume_size = 100           
  }
}

resource "aws_autoscaling_group" "webserver" {
  name                = "${var.namespace}-asg"
  min_size            = 1
  max_size            = 5
  vpc_zone_identifier = var.vpc.public_subnets
  target_group_arns   = module.alb.target_group_arns
  health_check_grace_period = 300
  health_check_type         = "ALB"
  desired_capacity          = 4
  force_delete              = true
  launch_template {
    id      = aws_launch_template.webserver.id
    version = aws_launch_template.webserver.latest_version
  }
  instance_maintenance_policy {
    min_healthy_percentage = 90
    max_healthy_percentage = 120
  }
}

module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 5.0"
  name               = var.namespace
  load_balancer_type = "application"
  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]

  http_tcp_listeners = [
    {
      port               = 80, #C
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    { name_prefix      = "websvr",
      backend_protocol = "HTTP",
      backend_port     = 8080
      target_type      = "instance"
    }
  ]
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = module.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "OK"
    }
  }
}

data "aws_instance" "ec2-asg-instance-info" {
instance_tags = {
name                = "${var.namespace}-asg"
}
depends_on = ["aws_autoscaling_group.webserver"]
}

data "aws_autoscaling_group" "webserver" {
{
  name = "${var.namespace}-asg"
}
depends_on = ["aws_autoscaling_group.webserver"]
}

output "asg_instance_ids" {
  value = data.aws_autoscaling_group.example.instances[*].id
}


resource "aws_ebs_volume" "root_volume" {
  count       = length(data.aws_instance.webapp_instances.id)
  availability_zone = var.availability_zone
  vpc_zone_identifier = var.vpc.private_subnets

  size = 50  
}



resource "aws_ebs_volume" "log_volume" {
  count       = length(aws_instance.webapp_instances)
  availability_zone = var.availability_zone
  vpc_zone_identifier = var.vpc.private_subnets
  size = 100  
}

resource "aws_volume_attachment" "example" {
  count       = length(data.aws_autoscaling_group.example.instances)
  volume_id   = "aws_ebs_volume.root_volume.id"
  instance_id = data.aws_autoscaling_group.webserver.instances[count.index].id
  device_name = "/dev/xvda" 
}

resource "aws_volume_attachment" "example" {
  count       = length(data.aws_autoscaling_group.example.instances)
  volume_id   = "aws_ebs_volume.log_volume.id"
  instance_id = data.aws_autoscaling_group.examplewebserver.instances[count.index].id
  device_name = "/dev/sdf" 
}

# resource "aws_volume_attachment" "webapp_volume_attachment" {
#   for_each = aws_instance.webapp_instances

#   volume_id          = aws_ebs_volume.root_volume[each.key].id
#   instance_id        = each.value.id
#   instance_id = "${data.aws_instance.ec2-asg-instance-info.ids[count.index]}"
#   device_name        = "/dev/sdf"  
# }
