
resource "docker_container" "web" {
  name  = "web-${terraform.workspace}-01"
  image = "lab/web"

   ports {
    internal = "80"
    external = var.web_port[terraform.workspace]
  }
}

resource "docker_container" "api" {
  name  = "api-${terraform.workspace}-01"
  image = "lab/api"

   ports {
    internal = "3000"
    external = var.api_port[terraform.workspace]
  }
}