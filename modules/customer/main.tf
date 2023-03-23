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
    module = "customer"
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
  account_id   = format("%s-customer", var.prefix)
  display_name = "Ephemeral sa for automated ibd-lite testing"
  description  = <<-EOD
  An ephemeral service account that will be used by emulated Customer services.
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
  name       = format("%s-customer", var.prefix)
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

resource "google_compute_instance_template" "customer" {
  for_each             = module.regions.results
  project              = var.project_id
  name_prefix          = format("%s-customer-%s-", var.prefix, each.value.abbreviation)
  description          = format("%s ephemeral customer environment (%s)", title(var.prefix), each.value.display_name)
  instance_description = format("%s ephemeral customer environment (%s)", title(var.prefix), each.value.display_name)
  region               = each.key
  labels               = local.labels
  metadata = {
    enable-oslogin         = "true"
    google-logging-enabled = "true"
    user-data = templatefile(format("%s/templates/cloud-config.yaml", path.module), {
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
  name      = format("%s-customer-healthz", var.prefix)
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
  name                = format("%s-customer-livez", var.prefix)
  check_interval_sec  = 10
  timeout_sec         = 1
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path = "/livez"
    response     = "customer-alive"
    port         = 26000
  }
}

resource "google_compute_region_instance_group_manager" "customer" {
  for_each           = module.regions.results
  project            = var.project_id
  name               = format("%s-customer-%s", var.prefix, each.value.abbreviation)
  base_instance_name = format("%s-customer-%s", var.prefix, each.value.abbreviation)
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
    name              = "customer"
    instance_template = google_compute_instance_template.customer[each.key].id
  }
}


resource "google_compute_health_check" "readyz" {
  project             = var.project_id
  name                = format("%s-customer-readyz", var.prefix)
  check_interval_sec  = 10
  timeout_sec         = 1
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path = "/readyz"
    response     = "customer-ready"
    port         = 80
  }
}

resource "google_compute_backend_service" "customer" {
  project               = var.project_id
  name                  = format("%s-customer", var.prefix)
  load_balancing_scheme = "EXTERNAL"
  port_name             = "http"
  protocol              = "HTTP"
  session_affinity      = "NONE"
  timeout_sec           = 5
  health_checks = [
    google_compute_health_check.readyz.id,
  ]
  dynamic "backend" {
    for_each = [for mig in google_compute_region_instance_group_manager.customer : mig.instance_group]
    content {
      group           = backend.value
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  }
}

resource "google_compute_global_network_endpoint_group" "ext_sse" {
  count                 = var.setup_external_sse ? 1 : 0
  project               = var.project_id
  name                  = format("%s-ext-sse", var.prefix)
  default_port          = 443
  network_endpoint_type = can(cidrhost(format("%s/32", var.sse), 0)) ? "INTERNET_IP_PORT" : "INTERNET_FQDN_PORT"
}

resource "google_compute_global_network_endpoint" "ext_sse" {
  count                         = var.setup_external_sse ? 1 : 0
  project                       = var.project_id
  global_network_endpoint_group = google_compute_global_network_endpoint_group.ext_sse[0].id
  ip_address                    = can(cidrhost(format("%s/32", var.sse), 0)) ? var.sse : null
  fqdn                          = can(cidrhost(format("%s/32", var.sse), 0)) ? null : var.sse
  port                          = google_compute_global_network_endpoint_group.ext_sse[0].default_port
}

resource "google_compute_backend_service" "ext_sse" {
  count       = var.setup_external_sse ? 1 : 0
  project     = var.project_id
  name        = format("%s-ext-sse", var.prefix)
  timeout_sec = 5
  protocol    = "HTTPS"
  custom_request_headers = [
    # Set the customer specific nonce to send to SSE backend
    format("X-Customer-Nonce: %s", var.customer_nonce),
  ]
  backend {
    group = google_compute_global_network_endpoint_group.ext_sse[0].id
  }
  # NOTE: The individual endpoints *MUST* be created before the backend service
  # is instantiated.
  depends_on = [
    google_compute_global_network_endpoint.ext_sse,
    google_compute_global_network_endpoint_group.ext_sse,
  ]
}

locals {
  sse_backends = toset(compact([try(google_compute_backend_service.ext_sse[0].id, null)]))
}

resource "google_compute_url_map" "customer" {
  project         = var.project_id
  name            = format("%s-customer", var.prefix)
  default_service = google_compute_backend_service.customer.id
  host_rule {
    hosts = [
      var.domain_name,
    ]
    path_matcher = "customer"
  }
  path_matcher {
    name = "customer"
    # Unmatched go to origin
    default_service = google_compute_backend_service.customer.id

    # Any request for ^/page-2/ with X-Shape-Nonce header matching the expected
    # value will be allowed through to origin, without retriggering an interception.
    dynamic "route_rules" {
      for_each = local.sse_backends
      content {
        priority = 100
        service  = google_compute_backend_service.customer.id
        match_rules {
          ignore_case  = false
          prefix_match = "/page-2/"
          header_matches {
            header_name = "X-Shape-Nonce"
            exact_match = var.sse_nonce
          }
        }
        # TODO @memes - this is for testing/verifying only and can be removed
        header_action {
          response_headers_to_add {
            header_name  = "X-Rule-Label"
            header_value = "permitted-by-shape"
            replace      = false
          }
        }
      }
    }

    # Request is a request matching ^/page-2/ with X-Customer-Intercept
    # header set to intercept value and x_customer_intercept parameter set to
    # intercept value
    dynamic "route_rules" {
      for_each = local.sse_backends
      content {
        priority = 200
        service  = route_rules.value
        match_rules {
          ignore_case  = false
          prefix_match = "/page-2/"
          header_matches {
            header_name = "X-Customer-Intercept"
            exact_match = var.intercept_token
          }
          query_parameter_matches {
            name        = "x_customer_intercept"
            exact_match = var.intercept_token
          }
        }
        # TODO @memes - this is for testing/verifying only and can be removed
        header_action {
          response_headers_to_add {
            header_name  = "X-Rule-Label"
            header_value = "intercept-both"
            replace      = false
          }
        }
      }
    }

    # Request is a request matching ^/page-2/ with X-Customer-Intercept
    # header set to intercept value.
    dynamic "route_rules" {
      for_each = local.sse_backends
      content {
        priority = 300
        service  = route_rules.value
        match_rules {
          ignore_case  = false
          prefix_match = "/page-2/"
          header_matches {
            header_name = "X-Customer-Intercept"
            exact_match = var.intercept_token
          }
        }
        # TODO @memes - this is for testing/verifying only and can be removed
        header_action {
          response_headers_to_add {
            header_name  = "X-Rule-Label"
            header_value = "intercept-header"
            replace      = false
          }
        }
      }
    }

    # Request is a request matching ^/page-2/ with x_customer_intercept
    # query parameter set to intercept value.
    dynamic "route_rules" {
      for_each = local.sse_backends
      content {
        priority = 400
        service  = route_rules.value
        match_rules {
          ignore_case  = false
          prefix_match = "/page-2/"
          query_parameter_matches {
            name        = "x_customer_intercept"
            exact_match = var.intercept_token
          }
        }
        # TODO @memes - this is for testing/verifying only and can be removed
        header_action {
          response_headers_to_add {
            header_name  = "X-Rule-Label"
            header_value = "intercept-param"
            replace      = false
          }
        }
      }
    }
  }
}

resource "google_compute_ssl_policy" "customer" {
  project         = var.project_id
  name            = format("%s-customer", var.prefix)
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "customer" {
  project         = var.project_id
  name            = format("%s-customer", var.prefix)
  ssl_policy      = google_compute_ssl_policy.customer.self_link
  certificate_map = var.certificate_map
  url_map         = google_compute_url_map.customer.id
}

resource "google_compute_global_forwarding_rule" "customer" {
  project               = var.project_id
  name                  = format("%s-customer", var.prefix)
  ip_address            = var.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  labels                = local.labels
  target                = google_compute_target_https_proxy.customer.id
}

resource "google_compute_firewall" "access" {
  project       = var.project_id
  name          = format("%s-customer-access", var.prefix)
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
