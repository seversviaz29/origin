# origin

Terraform как инструмент для декларативного описания инфраструктуры // ДЗ 
1)Прежде всего создал репозиторий в одном из облачных сервисов (Github) и склонировал его на рабочую станцию.

git clone git@github.com/seversviaz29/origin.git

2)Перешел в каталог с репозиторием и создал там директорию terraform:

mkdir terraform

Дополнительно создал файл .gitignore со следующим содержимым

**/.terraform/*

*.tfstate
*.tfstate.*

crash.log

*.tfvars
*.auto.tfvars

override.tf
override.tf.json
*_override.tf
*_override.tf.json

.terraformrc
terraform.rc


3) Создал файл provider.tf со следующим содержимым:

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud
  folder_id = var.yc_folder
}

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

4) Создал файл variables.tf:

variable "yc_cloud" {
  type = string
  description = "Yandex Cloud ID"
}

variable "yc_folder" {
  type = string
  description = "Yandex Cloud folder"
}

variable "yc_token" {
  type = string
  description = "Yandex Cloud OAuth token"
}

variable "db_password" {
  description = "MySQL user pasword"
}

5) Создал файл wp.auto.tfvars

yc_cloud  = "b1gf5768rgabjbptan7a"
yc_folder = "b1gem6odif0j9js8e1m5"
yc_token = "..."
db_password = "password"


Задание со *
Общение с YC, используя токен не самый надежный и удобный способ, поэтому попробуйте перейти на использования доступа через сервисный аккаунт.

yc iam service-account create --name terra --folder-id b1gem6odif0j9js8e1m5
yc resource-manager folder add-access-binding test --role editor --service-account-id aje3odqt7pta4al5o64l
yc iam key create --service-account-name terra --output $HOME/terra.json
yc config profile create terra
yc config set folder-id b1gem6odif0j9js8e1m5
yc config set service-account-key $HOME/terra.json

Экспортируем переменную YC_SERVICE_ACCOUNT_KEY_FILE
export YC_SERVICE_ACCOUNT_KEY_FILE=$HOME/terra.json

Удаляем yc_token из wp.auto.tfvars.
Редактируем provider.tf и проводим инцициализацию

provider "yandex" {
  service_account_key_file = file("/home/ubuntu/terra.json")
  cloud_id  = var.yc_cloud
  folder_id = var.yc_folder
}

terraform init


6) Создал файл network.tf со следующим содержимым:

resource "yandex_vpc_network" "wp-network" {
  name = "wp-network"
}

resource "yandex_vpc_subnet" "wp-subnet-a" {
  name = "wp-subnet-a"
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.wp-network.id
}

resource "yandex_vpc_subnet" "wp-subnet-b" {
  name = "wp-subnet-b"
  v4_cidr_blocks = ["10.3.0.0/16"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.wp-network.id
}

resource "yandex_vpc_subnet" "wp-subnet-c" {
  name = "wp-subnet-c"
  v4_cidr_blocks = ["10.4.0.0/16"]
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.wp-network.id
}

7) Проверил как работает данный манифест, выполнив команду:

terraform apply --auto-approve

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

8) Создал файл wp-app.tf со следующим содержимым:

resource "yandex_compute_instance" "wp-app-1" {
  name = "wp-app-1"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80viupr3qjr5g6g9du"
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-a
    subnet_id = yandex_vpc_subnet.wp-subnet-a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/yc.pub")}"
  }
}

resource "yandex_compute_instance" "wp-app-2" {
  name = "wp-app-2"
  zone = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80viupr3qjr5g6g9du"
    }
  }

  network_interface {
    # Указан id подсети default-ru-central1-b
    subnet_id = yandex_vpc_subnet.wp-subnet-b.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/yc.pub")}"
  }
}

Снова запустил команду применения манифестов и убедился, что виртуальные машины созданы успешно:

terraform apply --auto-approve
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

9)
Балансировщик трафика

Создал манифест lb.tf со следующим содержимым:

resource "yandex_lb_target_group" "wp_tg" {
  name      = "wp-target-group"

  target {
    subnet_id = yandex_vpc_subnet.wp-subnet-a.id
    address   = yandex_compute_instance.wp-app-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.wp-subnet-b.id
    address   = yandex_compute_instance.wp-app-2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "wp_lb" {
  name = "wp-network-load-balancer"

  listener {
    name = "wp-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.wp_tg.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/health"
      }
    }
  }
}

Запустил команду применения манифестов и убедился, что виртуальные машины созданы успешно:

terraform apply --auto-approve
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

10) задание со **
Обратите внимание, что в манифесте группы хостов для балансировщика мы явно указывали отдельные блоки target с именами виртуальных машин

address = yandex_compute_instance.wp-app-1.network_interface.0.ip_address

Понятно, что это может быть не очень удобное, если мы захотим уменьшить или увеличить кол-во хостов, где будет развернут WordPress.

Изменил манифесты создания виртуальных машин и балансировщика, чтобы кол-вом хостов можно было управлять при помощи переменной и при этом не требовалось бы вносить изменения в манифесты терраформа.

cat lb.tf
resource "yandex_lb_target_group" "wp_tg" {
  name      = "wp-target-group"
  dynamic "target" {
    for_each = yandex_compute_instance.wp-app.*.network_interface.0.ip_address
    content {
        subnet_id = yandex_vpc_subnet.wp-subnet-a.id
        address   = target.value
    }
  }

cat wp-app.tf
resource "yandex_compute_instance" "wp-app" {
  count = var.countofservers
  name = "wp-app-${count.index+1}"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

cat variables.tf
variable countofservers {
  description = "Count of servers"
  default     = 2
}


11) База данных

Создал db.tf
Содержимое манифеста будет:

locals {
  dbuser = tolist(yandex_mdb_mysql_cluster.wp_mysql.user.*.name)[0]
  dbpassword = tolist(yandex_mdb_mysql_cluster.wp_mysql.user.*.password)[0]
  dbhosts = yandex_mdb_mysql_cluster.wp_mysql.host.*.fqdn
  dbname = tolist(yandex_mdb_mysql_cluster.wp_mysql.database.*.name)[0]
}

resource "yandex_mdb_mysql_cluster" "wp_mysql" {
  name        = "wp-mysql"
  folder_id   = var.yc_folder
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.wp-network.id
  version     = "8.0"

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-ssd"
    disk_size          = 16
  }

  database {
    name  = "db"
  }

  user {
    name     = "user"
    password = var.db_password
    authentication_plugin = "MYSQL_NATIVE_PASSWORD"
    permission {
      database_name = "db"
      roles         = ["ALL"]
    }
  }

  host {
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.wp-subnet-b.id
    assign_public_ip = true
  }
  host {
    zone      = "ru-central1-c"
    subnet_id = yandex_vpc_subnet.wp-subnet-c.id
    assign_public_ip = true
  }
}

Запустил команду применения манифестов и убедился, что кластер баз данных создан успешно. 

terraform apply --auto-approve
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

12) Output-переменные

Создал файл output.tf.

Содержимое данного манифеста:

output "load_balancer_public_ip" {
  description = "Public IP address of load balancer"
  value = yandex_lb_network_load_balancer.wp_lb.listener.*.external_address_spec[0].*.address
}

output "database_host_fqdn" {
  description = "DB hostname"
  value = local.dbhosts
}

Запустил команду terraform apply еще раз
terraform apply --auto-approve
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:
database_host_fqdn = tolist([
  "rc1b-wflm6hz0mumifx4s.mdb.yandexcloud.net",
  "rc1c-rggytzrrgn3zk9r4.mdb.yandexcloud.net",
])
load_balancer_public_ip = tolist([
  "51.250.72.235",
])

13)
Удаление ресурсов
terraform destroy --auto-approve
Destroy complete! Resources: 9 destroyed.
