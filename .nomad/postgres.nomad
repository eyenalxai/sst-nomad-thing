variable "POSTGRES_PASSWORD" {
  type = string
}

variable "POSTGRES_USER" {
  type = string
}

variable "POSTGRES_DATABASE" {
  type = string
}

variable "DOMAIN" {
  type = string
}

job "postgres" {
  group "postgres-group" {
    network {
      mode = "bridge"

      port "database" {
        to = -1
      }
    }

    service {
      name = "postgres"
      provider = "nomad"
      port = "database"
      tags = [
        "database",
        "traefik.enable=true",
        "traefik.tcp.routers.db.rule=HostSNI(`database.${var.DOMAIN}`)",
        "traefik.tcp.routers.db.tls=true",
        "traefik.tcp.routers.db.entrypoints=database",
        "traefik.tcp.routers.db.tls.certresolver=myresolver",
        "traefik.tcp.services.db.loadbalancer.server.port=${NOMAD_PORT_database}"
      ]
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
        PGPORT = "${NOMAD_PORT_database}"
      }
    }
  }
}
