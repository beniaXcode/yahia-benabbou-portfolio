variable "name" {
  description = "Secrets Manager secret name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt this secret."
  type        = string
}

variable "reader_role_arns" {
  description = "IAM role ARNs (typically an External Secrets Operator Pod Identity role) allowed to read this secret's value at runtime. Terraform never writes a value here (C7) — only ESO does, after the fact."
  type        = list(string)
}

variable "recovery_window_in_days" {
  description = "Days AWS keeps a deleted secret recoverable before permanent deletion."
  type        = number
  default     = 30
}

variable "rotation_lambda_arn" {
  description = "Optional rotation Lambda ARN. When null (default), no rotation schedule is created — recognizing this reference platform ships no rotation Lambda of its own; a real deployment supplies one."
  type        = string
  default     = null
}

variable "rotation_days" {
  description = "Rotation interval, only used when rotation_lambda_arn is set."
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
