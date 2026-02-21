terraform {
  required_version = "~> 1.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "local" {
  # Configuration options
}

variable "test" {
  type = string
}

resource "local_file" "foo" {
  content  = format("%s / %s", var.test, timestamp())
  filename = "${path.module}/foo.bar"
}