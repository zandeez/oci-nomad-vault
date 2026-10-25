namespace "default" {
  policy = "write"
}

host_volume "*" {
  capabilities = ["mount-readwrite"]
}
