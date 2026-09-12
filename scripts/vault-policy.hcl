# Representative HashiCorp Vault policy — scopes a service to exactly the dynamic secrets it
# needs, with short TTLs so a leaked credential expires quickly.

# Dynamic database credentials, 1-hour TTL — service-a only reads its own database role.
path "database/creds/service-a-role" {
  capabilities = ["read"]
}

# Short-lived TLS certificate issuance for this service's mTLS identity.
path "pki/issue/service-a" {
  capabilities = ["create", "update"]
}

# No access to any other service's secrets or roles.
path "database/creds/*" {
  capabilities = ["deny"]
}

path "secret/data/service-a/*" {
  capabilities = ["read"]
}

# Explicit deny on the general secrets tree — access is allow-listed per path, not
# broad-then-restricted.
path "secret/data/*" {
  capabilities = ["deny"]
}
