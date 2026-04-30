variable "web_port" {
  type = map(number)
  default = {
    "default" = 8081
    "dev"     = 8082
    "prod"    = 80
  }
}

variable "api_port" {
  type = map(number)
  default = {
    "default" = 3000
    "dev"     = 3001
    "prod"    = 3000
  }
}
variable "DATABASE_ENDPOINT" {
  type = string
}

# SNS Email notifications
variable "enable_email_notifications" {
  description = "Habilitar notificaciones por email"
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Email para recibir notificaciones"
  type        = string
  default     = "admin@example.com"
}