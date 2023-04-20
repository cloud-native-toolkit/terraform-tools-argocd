terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
    clis = {
      source = "cloud-native-toolkit/clis"
    }
  }
  required_version = ">= 0.13"
}
