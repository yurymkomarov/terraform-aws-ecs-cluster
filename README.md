# AWS ECS Cluster

This module provides AWS ECS Cluster resources:
- ECS Cluster
- ECS Autoscaling group
- IAM Instance profile
- security group
- private key for ECS Cluster instances
- AWS Secrets Manager key for private key

## Input variables
- `name` - Name that will be used in resources names and tags
- `instance_type` - The EC2 instance type
- `spot_price` - The maximum price to use for reserving spot instances
- `vpc_id` - The identifier of the VPC in which to create the security group
- `vpc_zone_identifier` - A list of subnet IDs to launch resources in
- `vpc_cidr_block` - The VPC CIDR IP range for security group ingress rule
- `efs_enable` - Enable EFS mount for cluster instances
- `efs_storage_dns_name` - The DNS name for the EFS

## Output variables
- `ecs_cluster`
    - `name` - The name of the cluster
    - `id` - The Amazon Resource Name (ARN) that identifies the cluster
    - `arn` - The Amazon Resource Name (ARN) that identifies the cluster
- `secretsmanager_secret`
    - `id` - Amazon Resource Name (ARN) of the secret
    - `arn` - Amazon Resource Name (ARN) of the secret
    - `rotation_enabled` - Specifies whether automatic rotation is enabled for this secret
