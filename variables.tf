variable "region" {
  #  description = "Please, enter AWS Region to deploy this infrastructure"
  type    = string
  default = "eu-central-1"
} # region for deploy this infrastructure

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "allow_ports" {
  type    = list(any)
  default = ["80", "443"]
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = [
    "10.0.10.0/24",
  ]
}

variable "private_subnet_cidr" {
  default = [
    "10.0.20.0/24",
  ]
}
