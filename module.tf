terraform {
  backend "http" {}
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "5.6.0"
    }
  }
}

variable "tenancy_ocid" {
  description = "The tenancy OCID to manage the infrastructure in"
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the user to log in as"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key for API authentication"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the public key for API authentication"
  type        = string
}

variable "compartment_ocid" {
  description = "The OCID of compartment to create resources in"
  type        = string
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  private_key_path = var.private_key_path
  fingerprint      = var.fingerprint
  region           = "uk-london-1"
}

module "matrix-oci" {
  source    = "./matrix-oci"
  providers = {
    oci = oci
  }
  compartment_id = var.compartment_ocid
}
