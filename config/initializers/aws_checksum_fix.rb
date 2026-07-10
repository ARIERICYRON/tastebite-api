# Cloudflare R2 (and other S3-compatible services) don't support the extra
# checksum header the AWS SDK started sending by default. This restores the
# older, compatible behavior.
Aws.config.update(
  request_checksum_calculation: "when_required",
  response_checksum_validation: "when_required"
)
