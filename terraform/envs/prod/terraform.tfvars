# Placeholder IDs. Real values are set in the pipeline environment.
subscription_id          = "00000000-0000-0000-0000-000000000000"
entra_tenant_id          = "00000000-0000-0000-0000-000000000000"
kubernetes_version       = "1.34"
platform_admin_group_ids = ["11111111-1111-1111-1111-111111111111"]
authorized_ip_ranges     = ["203.0.113.0/24"]
acr_name                 = "acrplatproduks"
dns_zone_name            = "platform.example.co.uk"
acme_email               = "platform-team@example.co.uk"

tags = {
  owner       = "platform-team"
  cost-center = "CC-0001"
}
