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
# Configuración de la notificación de eventos de S3 para invocar AWS Lambda mediante AWS CLI 
Este proyecto despliega una arquitectura Serverless orientada a eventos en AWS utilizando Terraform. Implementa una función Lambda "Omnicanal" capaz de procesar y distinguir disparadores desde múltiples fuentes de aws.

## Integrantes:
- Rivera Chamorro, Kristel 
# **1. Herramientas utilizadas**:
   Para la construcción de esta arquitectura Serverless, se han seleccionado herramientas que garantizan el desacoplamiento y la automatización:
  + AWS CLI (v2): Interfaz de línea de comandos para gestionar los servicios sin usar la consola web, permitiendo scripts repetibles.
  + Amazon S3: Almacenamiento de objetos que actúa como el "Generador de Eventos".
  + AWS Lambda: Servicio de cómputo que procesa la lógica (imágenes o datos) al ser invocado.
  + Amazon SNS (Simple Notification Service): Motor de mensajería para distribuir las alertas finales.
  + JQ: Utilidad de procesado de JSON en terminal, vital para manipular las configuraciones de los buckets.

## **2.Diagramas de Arquitectura**:
   En el informe se han integrado representaciones visuales para diferenciar los dos flujos principales:
  + Diagrama de Invocación: Muestra cómo el PutObject en S3 dispara la Lambda.
  + Diagrama de Permisos: Ilustra la política basada en recursos que permite a S3 tener acceso a la función Lambda.
  + Diagrama de Fan-out: Representa cómo un solo evento puede terminar en múltiples destinos (Email, SMS, SQS).
## **2.1 SNS = "PUSH" (Empujar/Gritar)**:
 + Modelo: Pub/Sub (Publicar/Suscribir).
 + Comportamiento: En cuanto llega el mensaje, SNS intenta entregarlo inmediatamente a todos los suscriptores. No espera.
 + Nuestro caso: Si se publica en el tema, la Lambda se despierta al instante.
 + Uso ideal: Enviar emails de alerta, SMS, o avisar a múltiples sistemas a la vez (ej: "¡Se cayó el servidor!").
## **2.2 SQS = "PULL" (Almacenar/Esperar)**:
 + Modelo: Cola de Mensajes (Queue).
 + Comportamiento: Guarda el mensaje en un buzón y espera a que la Lambda tenga tiempo libre para venir a buscarlo.
 + Nuestro caso: La Lambda va "leyendo" la cola a su propio ritmo.
 + Uso ideal: Amortiguar picos de tráfico (ej: 1000 reservas en 1 segundo).

## **Comandos de ejecución**:
+ Antes de nada, activamos nuestra cuenta en aws y los IAM para en la terminal ejecutar el "aws configure sso"
+ Se selecciona un usuario, en nuestro caso usamos "Seabook"
+ Seguimos los pasos, y ya tenemos activado el aws

Para los archivos terraform, tenemos lo siguiente:
 + Inicialización:
```bash
terraform init
terraform update
```
  Gestión de entornos:

El proyecto utiliza la función terraform.workspace :para los recursos, así que se va a crear el usuario a trabajar
```bash
terraform workspace new dev (ejemplo)
```
Si ya existe más de uno entonces se escoje cual
```bash
terraform workspace select dev
```
Planificación: Se visualiza la sintaxis del código para asegurar que no hayan errores de esta misma
```bash
terraform plan
```
Despliegue: Para la creación de los servicios
```bash
terraform apply
```
+ Limpieza opcional: Al acabar, se pueden borrar todo lo creado
```bash
terraform destroy
```
## Consideraciones:

+ Costos y Retención:
 Se ha configurado una regla de ciclo de vida en CloudWatch Logs para borrar logs antiguos después de 14 días. Esto asegura que el proyecto se  mantenga dentro del Free Tier o con costo cercano a cero.
+ Nomenclaturización:
  Se utiliza la función lower() de Terraform para garantizar que el bucket de S3 cumpla con la normativa de AWS (solo minúsculas), independientemente del nombre del workspace (ej. "Seabook" -> "seabook").

Lógica de detección:

El archivo index.js maneja la discrepancia de capitalización de AWS:
```bash
    S3 usa eventSource (camelCase).
    SNS usa EventSource (PascalCase).
    SQS usa eventSource (camelCase).
```
Perfil de AWS:
El proyecto está configurado para usar el perfil local llamado "Seabook" (definido en main.tf). asegurar de tener este perfil en tu ~/.aws/credentials o actualiza el archivo main.tf.


> Revisa el **plan** antes del apply. Si lo prefieres: `-auto-approve` para saltar la confirmación sino confirmar con un "yes".

---
