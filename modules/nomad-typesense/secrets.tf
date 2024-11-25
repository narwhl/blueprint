resource "random_password" "typesense_api_key" {
  count   = var.typesense_api_key == "" ? 1 : 0
  length  = 20
  special = false
}
