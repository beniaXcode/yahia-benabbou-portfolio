variable "alias" {
  description = "KMS alias name, without the leading \"alias/\"."
  type        = string
}

variable "description" {
  description = "Human-readable description of what this key protects."
  type        = string
}

variable "account_id" {
  description = "AWS account ID this key is created in — needed to write an explicit key policy naming the account root as administrator, rather than relying on AWS's implicit default key policy."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "deletion_window_in_days" {
  description = "Waiting period before the key is actually deleted after a destroy."
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
