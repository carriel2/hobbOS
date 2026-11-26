variable "os_cloud" {
  description = "Nome da entrada no clouds.yaml com as credenciais do OpenStack"
  type        = string
}

variable "name" {
  description = "Prefixo dos recursos"
  type        = string
  default     = "hobbos"
}

variable "external_network_name" {
  description = "Rede externa (pública) usada pelo router e pelo floating IP"
  type        = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.40.0.0/24"
}

variable "dns_nameservers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "admin_cidrs" {
  description = "Redes que podem acessar o SSH de fora"
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrnetmask(c))])
    error_message = "Cada item de admin_cidrs deve ser um CIDR próprio, ex.: [\"203.0.113.10/32\"]."
  }
}

variable "image_name" {
  type    = string
  default = "Arch-Linux-x86_64-cloudimg.qcow2"
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_user" {
  description = "Usuário padrão da imagem cloud do Arch"
  type        = string
  default     = "arch"
}

variable "flavor" {
  description = "Flavor da VM de build (o mksquashfs aproveita bem vários núcleos)"
  type        = string
  default     = "PRI-4-8"
}

variable "volume_size_gb" {
  description = "Disco de boot: o build do archiso usa bastante espaço temporário"
  type        = number
  default     = 40
}

variable "volume_type" {
  description = "Tipo de volume do disco de boot (null = padrão do projeto)"
  type        = string
  default     = null
}
