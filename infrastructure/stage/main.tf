terraform {
  required_version = ">=1.6, <1.7"
  backend "s3" {
    key = "stage/terraform.state"
  }
}

variable "access_key" { type = string }
variable "secret_key" { type = string }
variable "region" { type = string }
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "state_bucket_prefix" { type = string }
variable "state_lock_table" { type = string }
module "s3" {
  source = "../global/s3"
  access_key = var.access_key
  region = var.region
  secret_key = var.secret_key
  state_bucket_prefix = var.state_bucket_prefix
  state_lock_table = var.state_lock_table
}
