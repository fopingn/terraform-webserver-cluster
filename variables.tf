
variable "region" {
  description = "The AWS region."
  default     = "us-east-1"
}

variable "key_name" {
  description = "The AWS key pair to use for resources. This have to be change to match your own key"
  default     = "name_key"
}

variable "instance_ips" {
  description = "The private IPs to use for our instances"
  default     = ["10.0.1.20", "10.0.1.21"]
}
