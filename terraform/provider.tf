provider "yandex" {
  service_account_key_file = file("/home/ubuntu/terra.json")
  cloud_id  = var.yc_cloud
  folder_id = var.yc_folder
}


/*provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud
  folder_id = var.yc_folder
}
*/
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}