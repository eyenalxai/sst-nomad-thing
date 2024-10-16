variable "NOMAD_URL" {
  type = string
}

job "traefik" {
  group "traefik-group" {
    network {
      mode = "host"

      port "http" {
        static = 80
      }

      port "http_secure" {
        static = 443
      }
    }

    service {
      name     = "traefik"
      provider = "nomad"
    }

    task "traefik-task" {
      driver = "docker"

      config {
        image = "traefik"
        ports = ["http", "http_secure"]
        volumes = ["/opt/letsencrypt:/letsencrypt", "/opt/traefik:/traefik"]
        args = [
          "--api.dashboard=false",
          "--api.insecure=true",
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entrypoints.websecure.address=:${NOMAD_PORT_http_secure}",
          "--entrypoints.websecure.http.tls=true",
          "--entrypoints.web.http.redirections.entrypoint.to=websecure",
          "--entrypoints.web.http.redirections.entrypoint.scheme=https",
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=${NOMAD_URL}",
          "--providers.nomad.exposedByDefault=false",
          "--accesslog=true",
          "--log.level=DEBUG",
          "--certificatesresolvers.myresolver.acme.dnschallenge=true",
          "--certificatesresolvers.myresolver.acme.dnschallenge.provider=cloudflare",
          "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json",
          "--providers.file.filename=/traefik/dynamic-config.yml"
        ]
      }

      env {
        NOMAD_URL = var.NOMAD_URL
      }

      template {
        data = <<EOF
CF_DNS_API_TOKEN="{{ key "traefik/cf_dns_api_token" }}"
EOF

        destination = "secrets/env"
        env         = true
      }

      identity {
        env         = true
        change_mode = "restart"
      }
    }
  }
}