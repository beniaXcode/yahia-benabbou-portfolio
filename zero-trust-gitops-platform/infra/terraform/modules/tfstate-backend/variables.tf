variable "bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state."
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name used for state locking."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt both the state bucket and the lock table."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
