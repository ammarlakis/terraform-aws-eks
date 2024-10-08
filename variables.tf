variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "The subnet IDs"
  type        = list(string)
}

variable "node_groups" {
  description = "The EKS nodegroups configuration"
  type = list(object({
    name             = string
    desired_capacity = number
    max_size         = number
    min_size         = number
    instance_type    = string
    }
  ))
}

variable "cluster_version" {
  description = "The cluster version"
  type        = string
}

variable "update_node_groups" {
  description = "A random value that triggers updating node groups "
  type        = any
}
