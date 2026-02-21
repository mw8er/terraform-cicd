tflint {
  required_version = ">= 0.50"
}

config {
  format = "compact"
  plugin_dir = "~/.tflint.d/plugins"

  call_module_type = "local"
  force = false
  disabled_by_default = false

  ignore_module = {
  }

  varfile = []
  variables = []
}

plugin "azurerm" {
    enabled = true
    version = "0.30.0"
    source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

plugin "avm" {
  enabled = true

  version = "0.2.0"
  source  = "github.com/Azure/tflint-ruleset-avm"
}
