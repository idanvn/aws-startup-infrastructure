variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.27"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "node_groups" {
  description = "EKS node groups configuration"
  type = map(object({
    instance_types = list(string)
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
  }))
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
