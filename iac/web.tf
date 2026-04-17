# --- IMÁGENES ---
resource "docker_image" "img_web" {
  name = "lab/web"
  build { context = "./src/web" }
}

resource "docker_image" "img_api" {
  name = "lab/api"
  build { context = "./src/api" }
}

# --- CONTENEDORES ---
resource "docker_container" "web" {
  name  = "web-${terraform.workspace}-01"
  image = docker_image.img_web.image_id
  networks_advanced { name = docker_network.app_network.name }
  ports {
    internal = 80
    external = var.web_port[terraform.workspace]
  }
}

resource "docker_container" "api" {
  name  = "api-${terraform.workspace}-01"
  image = docker_image.img_api.image_id
  networks_advanced { name = docker_network.app_network.name }
  ports {
    internal = 3000
    external = var.api_port[terraform.workspace]
  }
}