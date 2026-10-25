vault {
  address     = "https://10.0.0.73:8200"
  ca_cert     = "/etc/ssl/ca.pem"
  client_cert = "/etc/ssl/host.pem"
  client_key  = "/etc/ssl/key.pem"
}

auto_auth {
  method "cert" {

  }
}

template {
  source      = "/etc/vault.d/templates/ca.ctmpl"
  destination = "/etc/ssl/ca.pem"
}

template {
  source      = "/etc/vault.d/templates/key.ctmpl"
  destination = "/etc/ssl/key.pem"
  command     = "openssl x509 -in /etc/ssl/key.pem -out /etc/ssl/host.pem"
}

template {
  source      = "/etc/vault.d/templates/nomad.ctmpl"
  destination = "/etc/nomad.d/nomad.env"
}
