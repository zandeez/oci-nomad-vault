ui = true

storage "oci" {
  region           = "uk-london-1"
  namespace_name   = "<your-object-storage-namespace>"
  bucket_name	   = "vault"
  ha_enabled	   = "false"
}

listener "tcp" {
  address	= "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/tls.crt"
  tls_key_file  = "/opt/vault/tls/tls.key"
}

seal "ocikms" {
  key_id              = "ocid1.key.oc1..<your-kms-key-ocid>"
  crypto_endpoint     = "https://<your-vault-id>-crypto.kms.uk-london-1.oraclecloud.com"
  management_endpoint = "https://<your-vault-id>-management.kms.uk-london-1.oraclecloud.com"
}
