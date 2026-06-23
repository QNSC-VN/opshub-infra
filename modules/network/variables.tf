variable "name" { type = string }
variable "region" { type = string }
variable "azs" { type = list(string) }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "data_subnet_cidrs" { type = list(string) }
variable "multi_az_nat" {
  type    = bool
  default = false
}
variable "app_port" {
  type    = number
  default = 3000
}
variable "tags" {
  type    = map(string)
  default = {}
}
