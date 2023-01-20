terraform {
  required_version = ">= 0.12"

  required_providers {
    clis = {
      source = "cloud-native-toolkit/clis"
      version = ">= 0.2.0"
    }
  }
}
