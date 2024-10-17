variable "POSTGRES_USER" {
  type = string
}

variable "POSTGRES_PASSWORD" {
  type = string
}

variable "POSTGRES_DATABASE" {
  type = string
}

variable "DOMAIN" {
  type = string
}

job "echo" {
  group "echo-group" {
    count = 3

    network {
      mode = "bridge"

      port "http" {
        to = -1
      }
    }

    service {
      name = "echo"
      provider = "nomad"
      port = "http"
      tags = [
        "http-echo",
        "traefik.enable=true",
        "traefik.http.routers.http-echo.rule=Host(`${var.DOMAIN}`)",
        "traefik.http.routers.http-echo.entrypoints=websecure",
        "traefik.http.routers.http-echo.tls.certresolver=myresolver",
        "traefik.http.services.http-echo.loadbalancer.server.port=${NOMAD_PORT_http}"
      ]

      check {
        name     = "HTTP Echo Health"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "echo-task" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo"
        ports = ["http"]
        args  = ["-text=DATABASE_URL: ${DATABASE_URL}\n\nCURRENT_PORT: ${NOMAD_PORT_http}", "-listen=:${NOMAD_PORT_http}"]
      }

      template {
        data = <<EOF
{{- range nomadService "postgres" }}
DATABASE_URL=postgres://${var.POSTGRES_USER}:${var.POSTGRES_PASSWORD}@{{ .Address }}:{{ .Port }}/${var.POSTGRES_DATABASE}
{{- end }}
EOF
        destination = "secrets/env"
        env         = true
      }
    }
  }
}
