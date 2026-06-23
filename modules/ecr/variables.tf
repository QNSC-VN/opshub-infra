variable "repositories" {
  type    = list(string)
  default = ["opshub-api", "opshub-worker"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
