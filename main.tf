provider "vault" {
  address = var.vault_addr
  token = var.vault_token
}

data "terraform_remote_state" "creds" {
  backend = "remote"
  config = {
    organization = "danpeacock"
    workspaces = {
      name = "vault-fpe-setup"
    }
  }
}


data "vault_aws_access_credentials" "creds" {
  backend = data.terraform_remote_state.outputs.vault_aws_secret_backend_role.admin.backend
  role    = data.terraform_remote_state.outputs.vault_aws_secret_backend_role.admin.name
}

data "vault_transform_encode" "test" {
    path        = data.terraform_remote_state.outputs.transform.value
    role_name   = "payments"
    value       = var.ccn
}


provider "aws" {
  depends_on = [vault_aws_access_credentials]
  region     = var.region
  access_key = data.vault_aws_access_credentials.creds.access_key
  secret_key = data.vault_aws_access_credentials.creds.secret_key
}

resource "aws_dynamodb_table" "customers_db" {
  name           = "customers"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "customer_id"

  attribute {
    name = "customer_id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "customers_items" {
  table_name = aws_dynamodb_table.customers_db.name
  hash_key   = aws_dynamodb_table.customers_db.hash_key

  item = <<ITEM
{
  "customer_id": {"S": "1"},
  "FirstName": {"S": "Dan"},
  "Surname": {"S": "Peacock"},
  "CCN": {"S": "${data.vault_transform_encode.test.encoded_value}"}
}
ITEM
}
