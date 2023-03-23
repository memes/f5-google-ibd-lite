terraform {
  required_version = ">= 1.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.53"
    }
  }
}

locals {
  labels = merge({
    module = "sse"
  }, var.labels)
}

data "google_compute_image" "default" {
  project = "cos-cloud"
  family  = "cos-stable"
}

module "regions" {
  source  = "memes/region-detail/google"
  version = "1.1.0"
  regions = var.regions
}

resource "google_service_account" "sa" {
  project      = var.project_id
  account_id   = format("%s-sse", var.prefix)
  display_name = "Ephemeral sa for automated ibd-lite testing"
  description  = <<-EOD
  An ephemeral service account that will be used by emulated SSE services.
  EOD
}

resource "google_project_iam_member" "sa" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.sa.member
}

module "vpc" {
  source     = "memes/multi-region-private-network/google"
  version    = "1.0.1"
  project_id = var.project_id
  name       = format("%s-sse", var.prefix)
  regions    = var.regions
  options = {
    mtu                   = 1460
    delete_default_routes = false
    restricted_apis       = false
    routing_mode          = "GLOBAL"
    nat                   = false
    nat_tags              = null
    flow_logs             = false
  }
}

resource "google_compute_instance_template" "sse" {
  for_each             = module.regions.results
  project              = var.project_id
  name_prefix          = format("%s-sse-%s-", var.prefix, each.value.abbreviation)
  description          = format("%s ephemeral SSE environment (%s)", title(var.prefix), each.value.display_name)
  instance_description = format("%s ephemeral SSE environment (%s)", title(var.prefix), each.value.display_name)
  region               = each.key
  labels               = local.labels
  metadata = {
    enable-oslogin         = "true"
    google-logging-enabled = "true"
    user-data = templatefile(format("%s/templates/cloud-config.yaml", path.module), {
      origin          = format("https://%s", var.origin)
      uri_matcher     = "\\/page-2\\/"
      intercept_token = var.intercept_token
      customer_nonce  = var.customer_nonce
      sse_nonce       = var.sse_nonce
    })
  }
  machine_type = "e2-medium"
  scheduling {
    automatic_restart = true
    preemptible       = false
  }
  service_account {
    email = google_service_account.sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
  disk {
    auto_delete  = true
    boot         = true
    source_image = data.google_compute_image.default.self_link
    disk_type    = "pd-balanced"
    disk_size_gb = 20
    labels       = local.labels
  }

  can_ip_forward = false
  network_interface {
    subnetwork = [for k, v in module.vpc.subnets : v.self_link if v.region == each.key][0]
    # Adding a public IP for easy access to containers without NAT
    access_config {
    }
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    google_service_account.sa,
    module.vpc,
  ]
}

resource "google_compute_firewall" "healthz" {
  project   = var.project_id
  name      = format("%s-sse-healthz", var.prefix)
  network   = module.vpc.self_link
  direction = "INGRESS"
  priority  = 900
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]
  target_service_accounts = [
    google_service_account.sa.email,
  ]
  allow {
    protocol = "TCP"
    ports = [
      80,
      26000,
    ]
  }
  depends_on = [
    google_service_account.sa,
    module.vpc,
  ]
}

resource "google_compute_health_check" "livez" {
  project             = var.project_id
  name                = format("%s-sse-livez", var.prefix)
  check_interval_sec  = 10
  timeout_sec         = 1
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path = "/livez"
    response     = "sse-alive"
    port         = 26000
  }
}

resource "google_compute_region_instance_group_manager" "sse" {
  for_each           = module.regions.results
  project            = var.project_id
  name               = format("%s-sse-%s", var.prefix, each.value.abbreviation)
  base_instance_name = format("%s-sse-%s", var.prefix, each.value.abbreviation)
  region             = each.key
  target_size        = 1
  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.livez.id
    initial_delay_sec = 30
  }

  update_policy {
    type                           = "PROACTIVE"
    instance_redistribution_type   = "NONE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 3
    max_unavailable_fixed          = 0
    replacement_method             = "SUBSTITUTE"
  }
  version {
    name              = "sse"
    instance_template = google_compute_instance_template.sse[each.key].id
  }
}


resource "google_compute_health_check" "readyz" {
  project             = var.project_id
  name                = format("%s-sse-readyz", var.prefix)
  check_interval_sec  = 10
  timeout_sec         = 1
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path = "/readyz"
    response     = "sse-ready"
    port         = 80
  }
}

resource "google_compute_backend_service" "sse" {
  project               = var.project_id
  name                  = format("%s-sse", var.prefix)
  load_balancing_scheme = "EXTERNAL"
  port_name             = "http"
  protocol              = "HTTP"
  session_affinity      = "NONE"
  timeout_sec           = 10
  health_checks = [
    google_compute_health_check.readyz.id,
  ]
  dynamic "backend" {
    for_each = [for mig in google_compute_region_instance_group_manager.sse : mig.instance_group]
    content {
      group           = backend.value
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  }
}

resource "google_compute_url_map" "sse" {
  project         = var.project_id
  name            = format("%s-sse", var.prefix)
  default_service = google_compute_backend_service.sse.id
  host_rule {
    hosts = [
      var.domain_name,
    ]
    path_matcher = "sse"
  }
  path_matcher {
    name            = "sse"
    default_service = google_compute_backend_service.sse.id
  }
}

resource "google_compute_ssl_policy" "sse" {
  project         = var.project_id
  name            = format("%s-sse", var.prefix)
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "https" {
  project         = var.project_id
  name            = format("%s-https-sse", var.prefix)
  ssl_policy      = google_compute_ssl_policy.sse.self_link
  certificate_map = var.certificate_map
  url_map         = google_compute_url_map.sse.id
}

resource "google_compute_global_forwarding_rule" "https" {
  project               = var.project_id
  name                  = format("%s-https-sse", var.prefix)
  ip_address            = var.address
  ip_protocol           = "TCP"
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
  labels                = local.labels
  target                = google_compute_target_https_proxy.https.id
}

resource "google_compute_firewall" "access" {
  project       = var.project_id
  name          = format("%s-sse-access", var.prefix)
  network       = module.vpc.self_link
  direction     = "INGRESS"
  priority      = 900
  source_ranges = var.access_cidrs
  target_service_accounts = [
    google_service_account.sa.email,
  ]
  allow {
    protocol = "TCP"
    ports = [
      22,
      80,
    ]
  }
  depends_on = [
    google_service_account.sa,
    module.vpc,
  ]
}
