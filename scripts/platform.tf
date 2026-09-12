# Representative Terraform module — provisions the shared CI/CD platform infrastructure
# (container registry, self-hosted runners, ArgoCD namespace) as code, reviewed and applied
# through the same pipeline as application changes.

terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
  }
  backend "s3" {
    # Remote state — bucket/key/region supplied per environment, not hardcoded.
  }
}

variable "environment" {
  type        = string
  description = "Platform environment (e.g. staging, production)"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "platform.internal/environment" = var.environment
    }
  }
}

resource "kubernetes_namespace" "platform_shared" {
  metadata {
    name = "platform-shared"
    labels = {
      "platform.internal/environment" = var.environment
    }
  }
}

resource "kubernetes_resource_quota" "platform_shared_quota" {
  metadata {
    name      = "platform-shared-quota"
    namespace = kubernetes_namespace.platform_shared.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "20"
      "requests.memory" = "40Gi"
      "pods"            = "100"
    }
  }
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}
