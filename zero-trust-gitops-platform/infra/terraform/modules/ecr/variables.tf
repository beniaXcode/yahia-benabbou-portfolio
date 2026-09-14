variable "name" {
  description = "ECR repository name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt images at rest."
  type        = string
}

variable "build_role_arn" {
  description = "IAM role ARN (the GitHub OIDC build role) allowed to push images to this repository. Push-only, never pull-and-run permissions."
  type        = string
}

variable "pull_role_arns" {
  description = "IAM role ARNs (e.g. the cluster node role, Pod Identity roles) allowed to pull images from this repository. Pull-only, never push."
  type        = list(string)
}

variable "untagged_expiry_days" {
  description = "Days after which an untagged image is expired by the lifecycle policy."
  type        = number
  default     = 14
}

variable "keep_last_tagged_images" {
  description = "Number of most-recent tagged images to retain; older tagged images are expired."
  type        = number
  default     = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
