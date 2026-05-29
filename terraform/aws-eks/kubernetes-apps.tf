resource "kubernetes_deployment_v1" "auth_service" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "auth-service"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "auth-service"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "auth-service"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "auth-service"
        }
      }

      spec {
        container {
          name              = "auth-service"
          image             = "${aws_ecr_repository.auth_service.repository_url}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8001
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.authdb[0].metadata[0].name
            }
          }

          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "SECRET_KEY"
              }
            }
          }

          env {
            name = "MONGODB_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "MONGODB_URL"
              }
            }
          }

          env {
            name = "RABBITMQ_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "RABBITMQ_URL"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/api/v1/health"
              port = 8001
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/api/v1/health"
              port = 8001
            }
            initial_delay_seconds = 30
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.mongodb,
    kubernetes_deployment_v1.rabbitmq
  ]
}

resource "kubernetes_deployment_v1" "user_service" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "user-service"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "user-service"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "user-service"
        }
      }

      spec {
        container {
          name              = "user-service"
          image             = "${aws_ecr_repository.user_service.repository_url}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8002
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.authdb[0].metadata[0].name
            }
          }

          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "SECRET_KEY"
              }
            }
          }

          env {
            name = "MONGODB_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "MONGODB_URL"
              }
            }
          }

          env {
            name = "RABBITMQ_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "RABBITMQ_URL"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/api/v1/health"
              port = 8002
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/api/v1/health"
              port = 8002
            }
            initial_delay_seconds = 30
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.mongodb,
    kubernetes_deployment_v1.rabbitmq
  ]
}

resource "kubernetes_deployment_v1" "task_service" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "task-service"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "task-service"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "task-service"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "task-service"
        }
      }

      spec {
        container {
          name              = "task-service"
          image             = "${aws_ecr_repository.task_service.repository_url}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8003
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.authdb[0].metadata[0].name
            }
          }

          env {
            name  = "TASK_SERVICE_PORT"
            value = "8003"
          }

          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "SECRET_KEY"
              }
            }
          }

          env {
            name = "MONGODB_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "MONGODB_URL"
              }
            }
          }

          env {
            name = "RABBITMQ_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "RABBITMQ_URL"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/api/v1/health"
              port = 8003
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/api/v1/health"
              port = 8003
            }
            initial_delay_seconds = 30
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.mongodb,
    kubernetes_deployment_v1.rabbitmq,
    kubernetes_deployment_v1.user_service
  ]
}

resource "kubernetes_deployment_v1" "gateway" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "gateway"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "gateway"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "gateway"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "gateway"
        }
      }

      spec {
        container {
          name              = "gateway"
          image             = "nginx:1.27-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 80
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
          }

          readiness_probe {
            http_get {
              path = "/api/v1/health"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/api/v1/health"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }

            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }
          }
        }

        volume {
          name = "nginx-config"

          config_map {
            name = kubernetes_config_map_v1.gateway_nginx[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.auth_service,
    kubernetes_deployment_v1.user_service,
    kubernetes_deployment_v1.task_service
  ]
}

resource "kubernetes_deployment_v1" "frontend" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "frontend"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "frontend"
        }
      }

      spec {
        container {
          name              = "frontend"
          image             = "${aws_ecr_repository.frontend.repository_url}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }

            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.gateway]
}

