variable "prefix" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}[a-z0-9]$", var.prefix))
    error_message = "The prefix variable must must be 2 to 21 lowercase letters, digits, or hyphens; it must start with a letter and cannot end with a hyphen."
  }
  description = <<-EOD
  A prefix to apply to the name of all generated resources.
  EOD
}

variable "project_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id variable must must be 6 to 30 lowercase letters, digits, or hyphens; it must start with a letter and cannot end with a hyphen."
  }
  description = <<-EOD
  The GCP project identifier where the resources will be created.
  EOD
}

variable "regions" {
  type = list(string)
  validation {
    condition     = var.regions == null ? false : length(var.regions) > 0 && length(join("", [for region in var.regions : can(regex("^[a-z]{2,}-[a-z]{2,}[0-9]$", region)) ? "x" : ""])) == length(var.regions)
    error_message = "There must be at least one region entry, and it must be a valid Google Cloud region name."
  }
  description = <<-EOD
  The list of Compute Engine regions in which to create the customer resources.
  EOD
}

variable "labels" {
  type = map(string)
  validation {
    condition     = length(compact([for k, v in var.labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v)) ? "x" : ""])) == length(keys(var.labels))
    error_message = "Each label key:value pair must match expectations."
  }
  default     = {}
  description = <<-EOD
  An optional set of key:value string pairs that will be added to resources.
  EOD
}

variable "access_cidrs" {
  type = list(string)
  validation {
    condition     = var.access_cidrs == null ? true : length(compact([for cidr in var.access_cidrs : can(cidrhost(cidr, 0)) ? "x" : ""])) == length(var.access_cidrs)
    error_message = "Each permit_cidrs value must be a valid CIDR."
  }
  default     = []
  description = <<-EOD
  A list of CIDRs that will be used to permit access to emulated systems. If
  empty (default) a minimal CIDR access list will be generated.
  EOD
}

variable "customer_nonce" {
  type        = string
  description = <<-EOD
  A nonce value to use when customer LB sends requests to SSE endpoint. This
  value will be verified in the SSE service.
  EOD
}

variable "sse_nonce" {
  type        = string
  description = <<-EOD
  A nonce value to use when emulated SSE has inspected and approved the original
  request. This value will be verified in the customer URL map.
  EOD
}

variable "intercept_token" {
  type        = string
  description = <<-EOD
  A value to use that will trigger sending a request to SSE for inspection when
  added to X-Customer-Intercept header or as x_customer_intercept parameter.
  EOD
}

variable "setup_external_sse" {
  type    = bool
  default = true
}

variable "dns_zone_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.dns_zone_name))
    error_message = "The dns_zone_name variable must be a valid Cloud DNS zone name."
  }
  description = <<-EOD
  The name of a Cloud DNS zone that will be used for Certificate Manager
  DNS authorization.
  EOD
}
