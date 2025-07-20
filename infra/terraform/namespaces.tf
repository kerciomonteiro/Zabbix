# Multi-Application Namespace Management
# This file defines the namespaces for different applications in the AKS cluster

# Application namespaces variable
variable "application_namespaces" {
  description = "List of application namespaces to create in the AKS cluster"
  type = map(object({
    name        = string
    labels      = map(string)
    annotations = map(string)
    quotas = object({
      requests_cpu    = string
      requests_memory = string
      limits_cpu      = string
      limits_memory   = string
      pods            = number
      services        = number
      pvcs            = number
    })
  }))
  default = {
    zabbix = {
      name = "zabbix"
      labels = {
        "app.kubernetes.io/name"      = "zabbix"
        "app.kubernetes.io/component" = "monitoring"
        "app.kubernetes.io/part-of"   = "observability"
      }
      annotations = {
        "description" = "Zabbix monitoring application"
      }
      quotas = {
        requests_cpu    = "2000m"
        requests_memory = "4Gi"
        limits_cpu      = "4000m"
        limits_memory   = "8Gi"
        pods            = 20
        services        = 10
        pvcs            = 5
      }
    }
    # Example for future applications
    # prometheus = {
    #   name = "prometheus"
    #   labels = {
    #     "app.kubernetes.io/name"      = "prometheus"
    #     "app.kubernetes.io/component" = "metrics"
    #     "app.kubernetes.io/part-of"   = "observability"
    #   }
    #   annotations = {
    #     "description" = "Prometheus metrics collection"
    #   }
    #   quotas = {
    #     requests_cpu    = "1000m"
    #     requests_memory = "2Gi"
    #     limits_cpu      = "2000m"
    #     limits_memory   = "4Gi"
    #     pods            = 10
    #     services        = 5
    #     pvcs            = 3
    #   }
    # }
  }
}

# Default storage classes for different workload types
variable "storage_classes" {
  description = "Storage classes for different application needs"
  type = map(object({
    name           = string
    provisioner    = string
    parameters     = map(string)
    reclaim_policy = string
  }))
  default = {
    fast = {
      name        = "fast-ssd"
      provisioner = "disk.csi.azure.com"
      parameters = {
        storageaccounttype = "Premium_LRS"
        kind               = "Managed"
        cachingmode        = "ReadOnly"
      }
      reclaim_policy = "Retain"
    }
    standard = {
      name        = "standard-ssd"
      provisioner = "disk.csi.azure.com"
      parameters = {
        storageaccounttype = "StandardSSD_LRS"
        kind               = "Managed"
        cachingmode        = "ReadOnly"
      }
      reclaim_policy = "Delete"
    }
  }
}

# Network policies for namespace isolation
variable "enable_network_policies" {
  description = "Enable network policies for namespace isolation"
  type        = bool
  default     = true
}

# Pod security standards
variable "pod_security_standards" {
  description = "Pod security standards for different namespaces"
  type = map(object({
    enforce = string
    audit   = string
    warn    = string
  }))
  default = {
    default = {
      enforce = "baseline"
      audit   = "restricted"
      warn    = "restricted"
    }
    system = {
      enforce = "privileged"
      audit   = "privileged"
      warn    = "privileged"
    }
  }
}
