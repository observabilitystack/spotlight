# Specific variables
# ---------------------------------------------------------------------
variable "hcloud_token" { type = string }

variable "instance_size" {
  type    = string
  default = "cax11"
}

variable "datacenter" {
  type    = string
  default = "hel1"
}

variable "spotlight_aws_access_key" {
  type    = string
  sensitive = true
}

variable "spotlight_aws_secret_access_key" {
  type    = string
  sensitive = true
}
