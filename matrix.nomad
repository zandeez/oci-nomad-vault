job "matrix" {

  type = "service"

  datacenters = ["oci-london-1"]

  vault {
    policies = ["nomad"]
  }

  group "traefik" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "arm64"
    }

    network {
      port "http" { static = 80 }
      port "https" { static = 443 }
      port "traefik" { static = 8080 }
      mode = "host"
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    task "traefik" {
      driver = "podman"
      config {
        image        = "docker.io/library/traefik:2.10.3"
        args         = ["--configfile=/local/static.toml"]
        ports        = ["http", "https"]
        network_mode = "host"
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "http"

        check {
          type     = "http"
          port     = "traefik"
          path     = "/ping"
          interval = "10s"
          timeout  = "5s"
        }
      }

      template {
        data        = <<EOH
[[ fileContents "config/traefik/static.toml" ]]
        EOH
        destination = "local/static.toml"
        change_mode = "restart"
      }

      template {
        data        = <<EOH
[[ fileContents "config/traefik/dynamic.toml" ]]
        EOH
        destination = "local/dynamic.toml"
        change_mode = "noop"
      }

      template {
        data        = <<EOH
[[ fileContents "config/ca.ctmpl" ]]
        EOH
        destination = "local/ca.pem"
        change_mode = "script"
        change_script {
          command = "/usr/bin/touch"
          args    = ["local/dynamic.toml"]
        }
      }

      template {
        data        = <<EOH
[[ fileContents "config/client.ctmpl" ]]
        EOH
        destination = "local/client.pem"
        change_mode = "script"
        change_script {
          command = "/bin/touch"
          args    = ["local/dynamic.toml"]
        }
      }
    }
  }

  group "nginx" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "arm64"
    }

    network {
      port "http" { to = 80 }
    }

    task "nginx" {
      driver = "podman"
      config {
        image = "docker.io/library/nginx:1.24.0"
        ports = ["http"]

        volumes = [
          "local/:/usr/share/nginx/html"
        ]
      }

      template {
        data        = <<EOH
[[ fileContents "config/nginx/.well-known/matrix/server.json" ]]
        EOH
        destination = "local/.well-known/matrix/server.json"
        change_mode = "noop"
      }

      template {
        data        = <<EOH
[[ fileContents "config/nginx/.well-known/matrix/client.json" ]]
        EOH
        destination = "local/.well-known/matrix/client.json"
        change_mode = "noop"
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "http"

        check {
          type     = "http"
          port     = "http"
          path     = "/.well-known/matrix/server.json"
          interval = "10s"
          timeout  = "5s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.middlewares.nginx-replacepathregex.replacepathregex.regex=^/.well-known/matrix/(.*)",
          "traefik.http.middlewares.nginx-replacepathregex.replacepathregex.replacement=/.well-known/matrix/$1.json",
          "traefik.http.routers.nginx.middlewares=corsheaders@file,nginx-replacepathregex,platform@file",
          "traefik.http.routers.nginx.rule=Host(`example.com`) || Host(`www.example.com`)"
        ]
      }
    }
  }

  group "database" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "arm64"
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    network {
      port "postgres" { static = 5432 }
    }

    volume "postgresql" {
      type      = "host"
      read_only = false
      source    = "postgresql"
    }

    task "database" {
      driver = "podman"
      config {
        image = "docker.io/library/postgres:15.3"
        ports = ["postgres"]
      }

      env {
        POSTGRES_INITDB_ARGS = "--no-locale --encoding=UTF8"
      }

      volume_mount {
        volume      = "postgresql"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "postgres"

        check {
          type     = "tcp"
          port     = "postgres"
          interval = "10s"
          timeout  = "5s"
        }
      }
    }
  }

  group "coturn" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "arm64"
    }

    task "coturn" {
      driver = "podman"
      config {
        image        = "docker.io/coturn/coturn:4.6.2-r3"
        network_mode = "host"
        args         = ["-c", "/local/turnserver.conf"]

        volumes = [
          "../alloc/data:/var/lib/coturn"
        ]
      }

      template {
        data        = <<EOH
external-ip={{ env "meta.external_ip" }}
use-auth-secret
static-auth-secret={{ with secret "kv/data/coturn" }}{{ .Data.data.secret }}{{ end }}
realm=matrix.example.com
EOH
        destination = "local/turnserver.conf"
      }
    }
  }

  group "synapse" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "arm64"
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    network {
      # This is static otherwise we end up with a circular dependency in app services
      port "synapse" { static = 8008 }
    }

    volume "synapse" {
      type      = "host"
      read_only = false
      source    = "synapse"
    }

    task "synapse" {
      driver = "podman"
      config {
        image = "docker.io/matrixdotorg/synapse:v1.86.0"
        ports = ["synapse"]
      }

      volume_mount {
        volume      = "synapse"
        destination = "/alloc/data/media_store"
        read_only   = false
      }

      env {
        SYNAPSE_CONFIG_DIR = "/alloc/data"
        SYNAPSE_DATA_DIR   = "/alloc/data"
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "synapse"

        check {
          type     = "http"
          port     = "synapse"
          path     = "/health"
          interval = "10s"
          timeout  = "5s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.synapse.middlewares=corsheaders@file,platform@file",
          "traefik.http.routers.synapse.rule=Host(`matrix.example.com`)"
        ]
      }

      template {
        data          = <<EOH
[[ fileContents "config/synapse/homeserver.yaml" ]]
EOH
        destination   = "../alloc/data/homeserver.yaml"
      }

      template {
        data        = <<EOH
[[ fileContents "config/synapse/example.com.log.config" ]]
EOH
        destination = "../alloc/data/example.com.log.config"
      }

      template {
        data        = <<EOH
[[ fileContents "config/synapse/mautrix-signal-registration.yaml" ]]
EOH
        destination = "local/mautrix-signal-registration.yaml"
      }

      template {
        data        = <<EOH
[[ fileContents "config/synapse/appservice-irc-registration.yaml" ]]
EOH
        destination = "local/appservice-irc-registration.yaml"
      }

      template {
        data        = <<EOH
[[ fileContents "config/synapse/mx-puppet-slack-registration.yaml" ]]
EOH
        destination = "local/slack-registration.yaml"
      }
    }
  }

  group "signal" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "arm64"
    }

    volume "signal" {
      type      = "host"
      read_only = false
      source    = "signal"
    }

    network {
      port "signal" {}
    }

    restart {
      attempts = 3
      delay    = "15s"
      interval = "10m"
      mode     = "delay"
    }

    task "signald" {
      driver = "podman"
      config {
        image = "docker.io/signald/signald:0.23.2"
      }

      volume_mount {
        volume      = "signal"
        destination = "/signald"
        read_only   = false
      }
    }

    task "mautrix-signal" {
      driver = "podman"
      config {
        image   = "dock.mau.dev/mautrix/signal"
        ports   = ["signal"]
        volumes = [
          "local:/data"
        ]
      }

      volume_mount {
        volume      = "signal"
        destination = "/signald"
        read_only   = false
      }

      template {
        data        = <<EOH
[[ fileContents "config/mautrix-signal/config.yaml" ]]
EOH
        destination = "local/config.yaml"
      }

      template {
        data        = <<EOH
id: signal
EOH
        destination = "local/registration.yaml"
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "signal"
      }
    }
  }

  group "element" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "arm64"
    }

    network {
      port "http" { to = 80 }
    }

    task "element" {
      driver = "podman"
      config {
        image = "docker.io/vectorim/element-web:v1.11.34"
        ports = ["http"]
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "http"

        check {
          type     = "http"
          port     = "http"
          path     = "/config.json"
          interval = "10s"
          timeout  = "5s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.element.middlewares=corsheaders@file,platform@file",
          "traefik.http.routers.element.rule=Host(`element.example.com`)"
        ]
      }

      template {
        data        = <<EOH
[[ fileContents "config/element/config.json" ]]
EOH
        destination = "/app/config.json"
      }
    }
  }

  group "irc" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "amd64"
    }

    network {
      port "irc" {}
    }

    task "appservice-irc" {
      driver = "podman"
      config {
        image   = "docker.io/matrixdotorg/matrix-appservice-irc:release-1.0.0"
        ports   = ["irc"]
        volumes = [
          "local:/data"
        ]
      }

      template {
        data        = <<EOH
[[ fileContents "config/matrix-appservice-irc/passkey.pem" ]]
EOH
        destination = "local/passkey.pem"
      }

      template {
        data        = <<EOH
[[ fileContents "config/matrix-appservice-irc/config.yaml" ]]
EOH
        destination = "local/config.yaml"
      }

      template {
        data        = <<EOH
[[ fileContents "config/synapse/appservice-irc-registration.yaml" ]]
EOH
        destination = "local/appservice-registration-irc.yaml"
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "irc"
      }
    }
  }

  group "slack" {
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "amd64"
    }

    network {
      port "slack" {}
    }

    task "mx-puppet-slack" {
      driver = "podman"
      config {
        image = "docker.io/sorunome/mx-puppet-slack:latest"
        ports = ["slack"]
      }

      env {
        CONFIG_PATH       = "/local/config.yaml"
        REGISTRATION_PATH = "/local/registration.yaml"
      }

      template {
        data        = <<EOH
[[ fileContents "config/mx-puppet-slack/config.yaml" ]]
EOH
        destination = "local/config.yaml"
      }

      template {
        data        = <<EOH
[[ fileContents "config/synapse/mx-puppet-slack-registration.yaml" ]]
EOH
        destination = "local/registration.yaml"
      }

      service {
        provider     = "nomad"
        address_mode = "host"
        port         = "slack"
      }
    }
  }
}
