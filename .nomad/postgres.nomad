variable "POSTGRES_PASSWORD" {
  type = string
}

variable "POSTGRES_USER" {
  type = string
}

variable "POSTGRES_DATABASE" {
  type = string
}

job "postgres" {
  group "postgres-group" {
    network {
      mode = "bridge"

      port "database" {
        to = 5432
      }
    }

    service {
      name = "postgres"
      port = "database"
    }

    task "postgres-task" {
      driver = "docker"

      config {
        image = "docker.io/postgres"
        ports = ["database"]
        volumes = ["/opt/nomad/data/postgres:/var/lib/postgresql/data"]
      }

      env {
        POSTGRES_PASSWORD = var.POSTGRES_PASSWORD
        POSTGRES_USER = var.POSTGRES_USER
        POSTGRES_DB = var.POSTGRES_DATABASE
      }
    }
  }
}
