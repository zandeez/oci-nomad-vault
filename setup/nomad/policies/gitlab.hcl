namespace "default" {
  policy = "write"
}

host_volume "postgresql" {
  capabilities = ["mount-readwrite"]
}

host_volume "synapse" {
  capabilities = ["mount-readwrite"]
}

host_volume "signal" {
  capabilities = ["mount-readwrite"]
}
