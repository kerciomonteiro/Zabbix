# Kubernetes Resources Configuration
# This file contains all Kubernetes resources that will be created after AKS is deployed
# The provider configuration is in kubernetes-providers.tf

# Create application namespaces
resource "kubernetes_namespace" "applications" {
  for_each = var.application_namespaces

  metadata {
    name        = each.value.name
    labels      = merge(each.value.labels, local.common_tags)
    annotations = each.value.annotations
  }

  depends_on = [
    azurerm_kubernetes_cluster.main,
    time_sleep.wait_for_cluster
  ]
}

# Create resource quotas for each namespace
resource "kubernetes_resource_quota" "application_quotas" {
  for_each = var.application_namespaces

  metadata {
    name      = "${each.value.name}-quota"
    namespace = kubernetes_namespace.applications[each.key].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"           = each.value.quotas.requests_cpu
      "requests.memory"        = each.value.quotas.requests_memory
      "limits.cpu"             = each.value.quotas.limits_cpu
      "limits.memory"          = each.value.quotas.limits_memory
      "pods"                   = each.value.quotas.pods
      "services"               = each.value.quotas.services
      "persistentvolumeclaims" = each.value.quotas.pvcs
    }
  }

  depends_on = [
    kubernetes_namespace.applications,
    time_sleep.wait_for_cluster
  ]
}

# Create network policies for namespace isolation
resource "kubernetes_network_policy" "namespace_isolation" {
  for_each = var.enable_network_policies ? var.application_namespaces : {}

  metadata {
    name      = "${each.value.name}-isolation"
    namespace = kubernetes_namespace.applications[each.key].metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]

    # Allow ingress from same namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = each.value.name
          }
        }
      }
    }

    # Allow ingress from ingress controller
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "ingress-nginx"
          }
        }
      }
    }

    # Allow egress to same namespace
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = each.value.name
          }
        }
      }
    }

    # Allow egress to kube-system for DNS
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    # Allow egress to internet (be more restrictive in production)
    egress {
      # Allow egress to any destination (you can be more restrictive in production)
    }
  }

  depends_on = [
    kubernetes_namespace.applications,
    time_sleep.wait_for_cluster
  ]
}

# Create storage classes for different workload types
resource "kubernetes_storage_class" "workload_storage" {
  for_each = var.storage_classes

  metadata {
    name = each.value.name
  }

  storage_provisioner    = each.value.provisioner
  parameters             = each.value.parameters
  reclaim_policy         = each.value.reclaim_policy
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  depends_on = [
    azurerm_kubernetes_cluster.main,
    time_sleep.wait_for_cluster
  ]
}

# Pod Security Standards Labels for namespaces
resource "kubernetes_labels" "pod_security_standards" {
  for_each = var.enable_pod_security_standards ? var.application_namespaces : {}

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = kubernetes_namespace.applications[each.key].metadata[0].name
  }

  labels = {
    "pod-security.kubernetes.io/enforce" = lookup(var.application_namespaces[each.key], "pod_security_standard", var.default_pod_security_standard)
    "pod-security.kubernetes.io/audit"   = lookup(var.application_namespaces[each.key], "pod_security_standard", var.default_pod_security_standard)
    "pod-security.kubernetes.io/warn"    = lookup(var.application_namespaces[each.key], "pod_security_standard", var.default_pod_security_standard)
  }

  depends_on = [
    kubernetes_namespace.applications,
    time_sleep.wait_for_cluster
  ]
}
