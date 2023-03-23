variable "prefix" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,24}[a-z0-9]$", var.prefix))
    error_message = "The prefix variable must must be 2 to 26 lowercase letters, digits, or hyphens; it must start with a letter and cannot end with a hyphen."
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
  The GCP project identifier where the GKE cluster will be created.
  EOD
}

variable "address" {
  type = string
  validation {
    condition     = can(cidrhost(format("%s/32", var.address), 0))
    error_message = "The address variable must be a valid IP address."
  }
  description = <<-EOD
  The public IP address to assign to the NLB that will be ingress for Shape
  requests.
  EOD
}

variable "domain_name" {
  type = string
  validation {
    condition     = can(regex("^(?:[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "The domain_name variable must be a valid DNS name."
  }
  description = <<-EOD
  The public DNS name that will be used to configure SSE host matching in URL Map.
  EOD
}

variable "origin" {
  type = string
  validation {
    condition     = can(cidrhost(format("%s/32", var.origin), 0)) || can(regex("^(?:[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.)+[a-z]{2,63}$", var.origin))
    error_message = "The origin variable must be a valid IP address or DNS name."
  }
  description = <<-EOD
  The public IP address or public DNS name for the Customer ingress that will
  respond to traffic sent to it.
  EOD
}

variable "regions" {
  type = list(string)
  validation {
    condition     = var.regions == null ? false : length(var.regions) > 0 && length(join("", [for region in var.regions : can(regex("^[a-z]{2,}-[a-z]{2,}[0-9]$", region)) ? "x" : ""])) == length(var.regions)
    error_message = "There must be at least one region entry, and it must be a valid Google Cloud region name."
  }
  description = <<-EOD
  The list of Compute Engine regions in which to create the SSE resources.
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
    error_message = "Each access_cidrs value must be a valid CIDR."
  }
  default     = []
  description = <<-EOD
  A list of CIDRs that will be used to permit access to emulated SSE.
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

variable "certificate_map" {
  type = string
  validation {
    condition     = can(regex("^//certificatemanager.googleapis.com/projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/locations/global/certificateMaps/[a-z][a-z-0-9]+[a-z-0-9]$", var.certificate_map))
    error_message = "The certificate_map variable must be a valid Certificate Manager map URI."
  }
  description = <<-EOD
  The URI of the existing Certificate Manager map that should be used with
  the SSE ingress load balancer.
  EOD
}
