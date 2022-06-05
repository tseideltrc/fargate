variable cidr {
  type        = string
  default     = "10.10.0.0/16"
  description = "The IPv4 CIDR block for the VPC"
}

variable container_image {
  type        = string
  default     = "nginxdemos/hello"
  description = "Container Image for the web application"
}

variable container_port {
  type        = string
  default     = "80"
  description = "Port on which the container receives traffic"
}

variable stage {
  type        = string
  default     = "dev"
  description = "Stage of the current deployment, i.e. prod, dev, test"
}

variable desired_count {
  type        = number
  default     = 2
  description = "Number of tasks to run"
}
