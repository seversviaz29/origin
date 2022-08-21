variable "yc_cloud" {
  type = string
  description = "Yandex Cloud ID"
}

variable "yc_folder" {
  type = string
  description = "Yandex Cloud folder"
}

variable "db_password" {
  description = "MySQL user pasword"
}
variable countofservers {
  description = "Count of servers"
  default     = 2
}