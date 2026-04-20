# Lab01-iac-jueves

#  Proyecto: Laboratorio de Infraestructura como Código (IaC)

Este repositorio contiene la configuración para desplegar una arquitectura de contenedores (Web + API + DB) utilizando **Terraform** y **Docker**.

##  Comandos de Gestión (Docker)
Comandos utilizados para construir y probar las imágenes de forma manual:

* **Construir imagen Web:**
  ```bash
  docker build -t lab/web ./src/web
Construir imagen API:

```bash
docker build -t lab/api ./src/api
Ver contenedores activos:

```bash
docker ps
 Flujo de Trabajo con Terraform
Comandos ejecutados dentro de la carpeta /iac para el despliegue automatizado:

Inicializar el entorno:

```bash
terraform init
Gestionar Workspaces (Entornos):

```bash
terraform workspace new dev   # Crear entorno de desarrollo
terraform workspace list      # Ver entornos disponibles
Desplegar infraestructura:

```bash
terraform apply -auto-approve
Destruir infraestructura:

```bash
terraform destroy
Comandos de Limpieza
Para mantener el entorno limpio y evitar errores de configuración:

Eliminar archivos residuales de Terraform:

```bash
rm -rf .terraform
rm .terraform.lock.hcl
Limpiar archivos de Node en la raíz:

Bash
rm -rf node_modules
rm package.json package-lock.json
Corregir permisos del Socket de Docker:

Bash
sudo chmod 666 /var/run/docker.sock

Estructura del Proyecto
iac/main.tf: Configuración de proveedores y redes.

iac/variable.tf: Definición de mapas de puertos por workspace.

iac/web.tf: Definición de contenedores e imágenes.

iac/src/: Código fuente de la Web (Nginx) y API (Node.js).

Nota: Todos los comandos de Terraform deben ejecutarse dentro del directorio /iac.