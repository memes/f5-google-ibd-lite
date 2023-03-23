#!/bin/shell
#

PREFIX="${PREFIX:-ibd-lite-manual-customer}"
NEG_NAME="${NEG_NAME:-${PREFIX}-ext-sse}"
NEG_BACKEND_NAME="${NEG_BACKEND_NAME:-${PREFIX}-ext-sse}"
SSE_ADDRESS=""
SSE_FQDN="${SSE_FQDN:-sse.ibd-lite-manual.ephemeral.strangelambda.app}"
SSE_PORT="${SSE_PORT:-443}"
CUSTOMER_NONCE="${CUSTOMER_NONCE:-757FA666-C4A6-4587-967F-632C4E49AF1A}"

gcloud compute network-endpoint-groups create "${NEG_NAME}" \
    --network-endpoint-type "${SSE_ADDRESS:+internet-ip-port}${SSE_FQDN:+internet-fqdn-port}" \
    --global \
    --project "${PROJECT_ID}"

gcloud compute network-endpoint-groups update "${NEG_NAME}" \
    --add-endpoint "${SSE_ADDRESS:+ip=${SSE_ADDRESS}}${SSE_FQDN:+fqdn=${SSE_FQDN}},port=${SSE_PORT}" \
    --global \
    --project "${PROJECT_ID}"

gcloud compute network-endpoint-groups list-network-endpoints "${NEG_NAME}" \
    --global \
    --project "${PROJECT_ID}"

gcloud compute backend-services create "${NEG_BACKEND_NAME}" \
   --global \
   --protocol=HTTPS \
   --custom-request-header "X-Customer-Nonce: ${CUSTOMER_NONCE}" \
   --project "${PROJECT_ID}"

gcloud compute backend-services add-backend "${NEG_BACKEND_NAME}" \
  --network-endpoint-group "${NEG_NAME}" \
  --global-network-endpoint-group \
  --global \
  --project "${PROJECT_ID}"

gcloud compute url-maps export "${PREFIX}" \
    --project "${PROJECT_ID}" > "${PREFIX}.yaml"
