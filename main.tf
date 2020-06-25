locals {
  key_pair = {
    private = tls_private_key.this.private_key_pem
    public  = tls_private_key.this.public_key_openssh
  }

  user_data = <<-EOF
    #cloud-config
    repo_update: true
    repo_upgrade: all

    packages:
      - aws-cli

    bootcmd:
      - mkdir -p /etc/ecs
      - echo 'ECS_CLUSTER=${aws_ecs_cluster.this.name}' >> /etc/ecs/ecs.config
      - echo 'ECS_ENABLE_SPOT_INSTANCE_DRAINING=true' >> /etc/ecs/ecs.config
      - echo 'LANG=en_US.utf-8' >> /etc/environment
      - echo 'LC_ALL=en_US.utf-8' >> /etc/environment

    final_message: "The system is finally up, after $UPTIME seconds"
  EOF

  user_data_efs = <<-EOF
    #cloud-config
    repo_update: true
    repo_upgrade: all

    packages:
      - aws-cli
      - amazon-efs-utils

    bootcmd:
      - mkdir -p /etc/ecs
      - echo 'ECS_CLUSTER=${aws_ecs_cluster.this.name}' >> /etc/ecs/ecs.config
      - echo 'ECS_ENABLE_SPOT_INSTANCE_DRAINING=true' >> /etc/ecs/ecs.config
      - echo 'LANG=en_US.utf-8' >> /etc/environment
      - echo 'LC_ALL=en_US.utf-8' >> /etc/environment
      - mkdir -p /home/ec2-user/efs
      - mount -t nfs4 -o nfsvers=4.1,rsize=2048,wsize=2048,hard,timeo=600,retrans=2,noresvport ${try(var.efs_storage_dns_name, "")}:/ /home/ec2-user/efs
      - chown www-data:www-data /home/ec2-user/efs

    final_message: "The system is finally up, after $UPTIME seconds"
  EOF
}

resource "random_id" "this" {
  byte_length = 1

  keepers = {
    vpc_id               = var.vpc_id
    vpc_cidr_block       = var.vpc_cidr_block
    vpc_zone_identifier  = join("", var.vpc_zone_identifier)
    efs_enable           = var.efs_enable
    efs_storage_dns_name = var.efs_storage_dns_name
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-${random_id.this.hex}"

  tags = {
    Name      = var.name
    Module    = path.module
    Workspace = terraform.workspace
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = "4096"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret" "this" {
  name = "${var.name}-${random_id.this.hex}"

  tags = {
    Name      = var.name
    Module    = path.module
    Workspace = terraform.workspace
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(local.key_pair)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-${random_id.this.hex}"
  public_key = tls_private_key.this.public_key_openssh

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  default_cooldown          = 60
  desired_capacity          = length(var.vpc_zone_identifier)
  health_check_grace_period = 120
  health_check_type         = "EC2"
  launch_configuration      = aws_launch_configuration.this.id
  min_size                  = length(var.vpc_zone_identifier)
  max_size                  = length(var.vpc_zone_identifier) * 2
  name                      = "${var.name}-${data.aws_ami.this.image_id}-${md5(var.efs_enable ? local.user_data_efs : local.user_data)}-${random_id.this.hex}"
  vpc_zone_identifier       = var.vpc_zone_identifier

  tags = [
    {
      key                 = "Name"
      value               = var.name
      propagate_at_launch = true
    },
    {
      key                 = "Module"
      value               = path.module
      propagate_at_launch = true
    },
    {
      key                 = "Workspace"
      value               = terraform.workspace
      propagate_at_launch = true
    }
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "spot" {
  name                      = "${var.name}-${random_id.this.hex}"
  policy_type               = "TargetTrackingScaling"
  adjustment_type           = "ChangeInCapacity"
  autoscaling_group_name    = aws_autoscaling_group.this.name
  metric_aggregation_type   = "Average"
  estimated_instance_warmup = 60

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value     = 75.0
    disable_scale_in = false
  }
}

resource "aws_launch_configuration" "this" {
  enable_monitoring           = true
  iam_instance_profile        = aws_iam_instance_profile.this.name
  image_id                    = data.aws_ami.this.id
  instance_type               = var.instance_type
  spot_price                  = var.spot_price
  key_name                    = aws_key_pair.this.key_name
  name                        = "${var.name}-${data.aws_ami.this.image_id}-${md5(var.efs_enable ? local.user_data_efs : local.user_data)}-${random_id.this.hex}"
  security_groups             = [aws_security_group.this.id]
  associate_public_ip_address = true
  user_data                   = var.efs_enable ? local.user_data_efs : local.user_data

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-${random_id.this.hex}"
  path = "/"
  role = aws_iam_role.this.name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = "${var.name}-${random_id.this.hex}"
  path               = "/"

  tags = {
    Name      = var.name
    Module    = path.module
    Workspace = terraform.workspace
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-${random_id.this.hex}"
  policy = data.aws_iam_policy_document.role_policy.json
  role   = aws_iam_role.this.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-${random_id.this.hex}"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
