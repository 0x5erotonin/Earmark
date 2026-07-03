variable "app_name" {
  description = "Globally-unique Fly app name (also the .fly.dev subdomain)"
  type        = string
}

variable "org" {
  description = "Fly organization slug (see `fly orgs list`)"
  type        = string
  default     = "personal"
}

variable "primary_region" {
  description = "Fly region for the machine + volume (see `fly platform regions`)"
  type        = string
  default     = "iad"
}

variable "image" {
  description = "Container image to run, e.g. registry.fly.io/<app>:v1"
  type        = string
}

variable "volume_name" {
  description = "Name of the persistent volume (matches fly.toml [mounts].source)"
  type        = string
  default     = "earmark_data"
}

variable "volume_size_gb" {
  description = "Volume size in GB"
  type        = number
  default     = 1
}

variable "cpus" {
  description = "Shared vCPUs for the machine"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "Machine memory in MB"
  type        = number
  default     = 512
}

variable "custom_domain" {
  description = "Optional custom domain (empty string = skip cert)"
  type        = string
  default     = ""
}
