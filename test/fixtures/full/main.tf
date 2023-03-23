terraform {
  required_version = ">= 1.2"
  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = ">= 3.2"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 4.53"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

data "http" "my_address" {
  url = "https://checkip.amazonaws.com"
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to get local IP address"
    }
  }
}

data "dns_txt_record_set" "gcp" {
  host = "_cloud-eoips.googleusercontent.com"
}

data "google_dns_managed_zone" "domain" {
  project = var.project_id
  name    = var.dns_zone_name
}

module "regions" {
  source  = "memes/region-detail/google"
  version = "1.1.0"
  regions = var.regions
}

locals {
  # To cover all possiblities, the calculated set of source CIDRs for backend
  # access is:
  # 1. GCP L7 proxy sources (same as health check): 35.191.0.0/16, 130.211.0.0/22
  # 2. Inter-GLB traffic
  #    a. SSE will receive requests from GFE (pull from DNS)
  #    b. Customer must accept requests from NAT'd SSE (regional CIDR)
  # 3. The testing source
  sse_cidrs      = coalescelist(var.access_cidrs, flatten(concat([format("%s/32", trimspace(data.http.my_address.response_body)), "35.191.0.0/16", "130.211.0.0/22"], [for record in data.dns_txt_record_set.gcp.records : regexall("ip4:((?:[0-9]+\\.){3}[0-9]+/[0-9]+)", record)]...)))
  customer_cidrs = coalescelist(var.access_cidrs, flatten(concat([format("%s/32", trimspace(data.http.my_address.response_body)), "35.191.0.0/16", "130.211.0.0/22"], [for k, v in module.regions.results : v.ipv4]...)))
  labels = merge({
    driver = "kitchen-terraform"
    prefix = var.prefix
  }, var.labels)
  sse_endpoint_fqdn      = trimsuffix(format("sse.%s.%s", var.prefix, data.google_dns_managed_zone.domain.dns_name), ".")
  customer_endpoint_fqdn = trimsuffix(format("customer.%s.%s", var.prefix, data.google_dns_managed_zone.domain.dns_name), ".")
}

resource "google_compute_global_address" "sse" {
  provider     = google-beta
  project      = var.project_id
  name         = format("%s-sse", var.prefix)
  description  = format("Emulated SSE endpoint address (%s)", var.prefix)
  labels       = local.labels
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

resource "google_compute_global_address" "customer" {
  provider     = google-beta
  project      = var.project_id
  name         = format("%s-customer", var.prefix)
  description  = format("Emulated customer endpoint address (%s)", var.prefix)
  labels       = local.labels
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

resource "google_dns_record_set" "sse_a" {
  project      = var.project_id
  name         = format("%s.", local.sse_endpoint_fqdn)
  managed_zone = data.google_dns_managed_zone.domain.name
  type         = "A"
  ttl          = 300
  rrdatas = [
    google_compute_global_address.sse.address,
  ]
}

resource "google_dns_record_set" "customer_a" {
  project      = var.project_id
  name         = format("%s.", local.customer_endpoint_fqdn)
  managed_zone = data.google_dns_managed_zone.domain.name
  type         = "A"
  ttl          = 300
  rrdatas = [
    google_compute_global_address.customer.address,
  ]
}

resource "google_certificate_manager_dns_authorization" "sse" {
  project     = var.project_id
  name        = format("%s-sse", var.prefix)
  description = format("Authorisation for %s TLS cert", local.sse_endpoint_fqdn)
  domain      = local.sse_endpoint_fqdn
  labels      = local.labels
}

resource "google_certificate_manager_dns_authorization" "customer" {
  project     = var.project_id
  name        = format("%s-customer", var.prefix)
  description = format("Authorisation for %s TLS cert", local.customer_endpoint_fqdn)
  domain      = local.customer_endpoint_fqdn
  labels      = local.labels
}

resource "google_dns_record_set" "sse_auth" {
  project      = var.project_id
  name         = google_certificate_manager_dns_authorization.sse.dns_resource_record[0].name
  managed_zone = data.google_dns_managed_zone.domain.name
  type         = google_certificate_manager_dns_authorization.sse.dns_resource_record[0].type
  ttl          = 300
  rrdatas = [
    google_certificate_manager_dns_authorization.sse.dns_resource_record[0].data,
  ]
}

resource "google_dns_record_set" "customer_auth" {
  project      = var.project_id
  name         = google_certificate_manager_dns_authorization.customer.dns_resource_record[0].name
  managed_zone = data.google_dns_managed_zone.domain.name
  type         = google_certificate_manager_dns_authorization.customer.dns_resource_record[0].type
  ttl          = 300
  rrdatas = [
    google_certificate_manager_dns_authorization.customer.dns_resource_record[0].data,
  ]
}

resource "google_certificate_manager_certificate" "sse" {
  project     = var.project_id
  name        = format("%s-sse", var.prefix)
  description = "TLS certificate for SSE endpoint"
  managed {
    domains = [
      local.sse_endpoint_fqdn,
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.sse.id,
    ]
  }
  labels = local.labels
}

resource "google_certificate_manager_certificate" "customer" {
  project     = var.project_id
  name        = format("%s-customer", var.prefix)
  description = "TLS certificate for Customer endpoint"
  managed {
    domains = [
      local.customer_endpoint_fqdn,
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.customer.id,
    ]
  }
  labels = local.labels
}

resource "google_certificate_manager_certificate_map" "certs" {
  project     = var.project_id
  name        = var.prefix
  description = "TLS certificate map for ibd-lite"
  labels      = local.labels
}

resource "google_certificate_manager_certificate_map_entry" "sse" {
  project     = var.project_id
  name        = format("%s-sse", var.prefix)
  description = "TLS certificate entry for SSE endpoint"
  hostname    = local.sse_endpoint_fqdn
  map         = google_certificate_manager_certificate_map.certs.name
  certificates = [
    google_certificate_manager_certificate.sse.id,
  ]
  labels = local.labels
}

resource "google_certificate_manager_certificate_map_entry" "customer" {
  project     = var.project_id
  name        = format("%s-customer", var.prefix)
  description = "TLS certificate entry for Customer endpoint"
  hostname    = local.customer_endpoint_fqdn
  map         = google_certificate_manager_certificate_map.certs.name
  certificates = [
    google_certificate_manager_certificate.customer.id,
  ]
  labels = local.labels
}

module "sse" {
  source          = "./../../../modules/sse/"
  project_id      = var.project_id
  prefix          = var.prefix
  address         = google_compute_global_address.sse.address
  origin          = local.customer_endpoint_fqdn
  regions         = var.regions
  labels          = local.labels
  access_cidrs    = local.sse_cidrs
  customer_nonce  = var.customer_nonce
  sse_nonce       = var.sse_nonce
  intercept_token = var.intercept_token
  domain_name     = local.sse_endpoint_fqdn
  certificate_map = format("//certificatemanager.googleapis.com/%s", google_certificate_manager_certificate_map.certs.id)
}

module "customer" {
  source             = "./../../../modules/customer/"
  project_id         = var.project_id
  prefix             = var.prefix
  address            = google_compute_global_address.customer.address
  sse                = local.sse_endpoint_fqdn
  regions            = var.regions
  labels             = local.labels
  access_cidrs       = local.customer_cidrs
  customer_nonce     = var.customer_nonce
  sse_nonce          = var.sse_nonce
  intercept_token    = var.intercept_token
  setup_external_sse = var.setup_external_sse
  domain_name        = local.customer_endpoint_fqdn
  certificate_map    = format("//certificatemanager.googleapis.com/%s", google_certificate_manager_certificate_map.certs.id)
}
