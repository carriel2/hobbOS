terraform {
  required_version = ">= 1.9"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4"
    }
  }
}

# Credenciais vêm do clouds.yaml local (fora do Git), escolhido por nome.
provider "openstack" {
  cloud = var.os_cloud
}
