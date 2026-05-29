resource "kubernetes_service_v1" "mongodb" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "mongodb"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "mongodb"
    }

    port {
      name        = "mongodb"
      port        = 27017
      target_port = 27017
    }
  }
}

resource "kubernetes_service_v1" "rabbitmq" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "rabbitmq"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }
  }
}

resource "kubernetes_service_v1" "auth_service" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "auth-service"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "auth-service"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "auth-service"
    }

    port {
      name        = "http"
      port        = 8001
      target_port = 8001
    }
  }
}

resource "kubernetes_service_v1" "user_service" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "user-service"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "user-service"
    }

    port {
      name        = "http"
      port        = 8002
      target_port = 8002
    }
  }
}

resource "kubernetes_service_v1" "task_service" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "task-service"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "task-service"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "task-service"
    }

    port {
      name        = "http"
      port        = 8003
      target_port = 8003
    }
  }
}

resource "kubernetes_service_v1" "gateway" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "gateway"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "gateway"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "gateway"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_service_v1" "frontend" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "frontend"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name" = "frontend"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }

  depends_on = [kubernetes_deployment_v1.frontend]
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "frontend" {
  count = var.deploy_kubernetes && var.enable_hpa ? 1 : 0

  metadata {
    name      = "frontend-hpa"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.frontend[0].metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "auth_service" {
  count = var.deploy_kubernetes && var.enable_hpa ? 1 : 0

  metadata {
    name      = "auth-service-hpa"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.auth_service[0].metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "user_service" {
  count = var.deploy_kubernetes && var.enable_hpa ? 1 : 0

  metadata {
    name      = "user-service-hpa"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.user_service[0].metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "task_service" {
  count = var.deploy_kubernetes && var.enable_hpa ? 1 : 0

  metadata {
    name      = "task-service-hpa"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.task_service[0].metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

