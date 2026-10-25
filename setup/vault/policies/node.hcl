# Load the CA Root Certificate
path "pki/cert/ca" {
  capabilities = ["read"]
}

# Request TLS Certificates
path "pki/issue/node" {
  capabilities = ["create", "update"]
}

# Allow creating tokens under "nomad" token role.
path "auth/token/create/nomad" {
  capabilities = ["update"]
}

# Allow looking up "nomad" token role.
path "auth/token/roles/nomad" {
  capabilities = ["read"]
}

# Allow creating tokens under "node" token role.
path "auth/token/create/node" {
  capabilities = ["update"]
}

# Allow looking up "node" token role.
path "auth/token/roles/node" {
  capabilities = ["read"]
}

# Required to revoke tokens
path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}
