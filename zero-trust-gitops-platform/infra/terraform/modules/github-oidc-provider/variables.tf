variable "github_org" {
  description = "GitHub organization or user that owns the repository (case-sensitive, as GitHub issues it in the OIDC subject claim)."
  type        = string
}

variable "github_repo" {
  description = "Repository name (without the owner prefix)."
  type        = string
}

variable "build_ref" {
  description = "The exact git ref (e.g. refs/heads/main) the build role trusts. Never a wildcard."
  type        = string
  default     = "refs/heads/main"
}

variable "deploy_environments" {
  description = "One deploy role is created per entry, each trusted only for that exact GitHub Environment name."
  type        = list(string)

  validation {
    condition     = length(var.deploy_environments) > 0
    error_message = "deploy_environments must list at least one GitHub Environment."
  }
}

variable "oidc_audience" {
  description = "Expected OIDC audience claim."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "max_session_duration" {
  description = "Ceiling (seconds) on how long a session assumed from this role may last; AWS requires this between 3600 and 43200. This is a maximum, not a target — the actual per-run session (typically 900s / 15 minutes) is requested by the caller (e.g. aws-actions/configure-aws-credentials' role-duration-seconds) and can be, and should be, far shorter than this ceiling."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "AWS requires max_session_duration to be between 3600 and 43200 seconds."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
