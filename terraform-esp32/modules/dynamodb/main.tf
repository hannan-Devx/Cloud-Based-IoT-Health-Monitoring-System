resource "aws_dynamodb_table" "esp32_vitals" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"   # On-demand – no capacity planning needed

  # Partition key: device_id (String)
  hash_key  = "device_id"
  # Sort key: timestamp (Number)
  range_key = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # TTL – attribute name matches what you set in the console (expiry_time)
  ttl {
    attribute_name = "expiry_time"
    enabled        = true
  }

  tags = {
    Project = "ESP32HealthMonitor"
  }
}
