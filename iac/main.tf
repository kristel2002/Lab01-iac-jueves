terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.2.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Creamos una red para que los contenedores se hablen por nombre
resource "docker_network" "app_network" {
  name = "network-${terraform.workspace}"
}

provider "aws" {
  # Configuration options
    profile = "Seabook"
    region  = "us-east-1"

    default_tags {
        tags = {
          Environment = terraform.workspace
          Application = "seabook"
          ManagedBy   = "Terraform" 
     }
    }
}