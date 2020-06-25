terraform {
  experiments = [variable_validation]
}

variable "name" {
  type        = string
  description = "Name that will be used in resources names and tags."
  default     = "terraform-aws-ecs-cluster"
}

variable "instance_type" {
  type        = string
  description = "The EC2 instance type."
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge"], var.instance_type)
    error_message = "Must be a valid Amazon EC2 instance type."
  }
}

variable "spot_price" {
  type        = number
  description = "The maximum price to use for reserving spot instances."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "The identifier of the VPC in which to create the security group."
}

variable "vpc_zone_identifier" {
  type        = list(string)
  description = "A list of subnet IDs to launch resources in."
}

variable "vpc_cidr_block" {
  type        = string
  description = "The VPC CIDR IP range for security group ingress rule."

  validation {
    condition     = can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/(0|[1-9]|1[0-9]|2[0-9]|3[0-2]))$", var.vpc_cidr_block))
    error_message = "CIDR parameter must be in the form x.x.x.x/0-32."
  }
}

variable "efs_enable" {
  type        = bool
  description = "Enable EFS mount for cluster instances."
  default     = false
}

variable "efs_storage_dns_name" {
  type        = string
  description = "The DNS name for the EFS."
  default     = ""
}
