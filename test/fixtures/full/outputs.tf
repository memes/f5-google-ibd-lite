output "sse_url" {
  value = format("https://%s", local.sse_endpoint_fqdn)
}

output "sse_address" {
  value = google_compute_global_address.sse.address
}

output "customer_url" {
  value = format("https://%s", local.customer_endpoint_fqdn)
}

output "customer_address" {
  value = google_compute_global_address.customer.address
}

output "customer_url_map" {
  value = module.customer.url_map
}
