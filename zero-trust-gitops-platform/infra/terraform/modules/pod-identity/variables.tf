variable "workload_name" {
  description = "Used to name the IAM role (e.g. \"demo-api\")."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  description = "Kubernetes namespace the association is scoped to."
  type        = string
}

variable "service_account" {
  description = "Kubernetes ServiceAccount name the association is scoped to. Only pods running as this exact ServiceAccount, in this exact namespace, on this exact cluster, can assume this role."
  type        = string
}

variable "permissions_policy_json" {
  description = "IAM policy JSON (e.g. from jsonencode(...) or aws_iam_policy_document) granting exactly what this workload needs — least privilege, scoped to specific resource ARNs, decided by the caller rather than this generic module."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
