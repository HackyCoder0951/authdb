resource "kubernetes_namespace_v1" "authdb" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name" = var.project_name
    }
  }

  depends_on = [aws_eks_addon.coredns]
}

resource "kubernetes_secret_v1" "authdb" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "authdb-secret"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.project_name
    }
  }

  type = "Opaque"

  data = {
    SECRET_KEY            = local.jwt_secret_key
    RABBITMQ_DEFAULT_USER = var.rabbitmq_username
    RABBITMQ_DEFAULT_PASS = local.rabbitmq_password
    RABBITMQ_URL          = local.rabbitmq_url
    MONGODB_ROOT_USER     = var.mongodb_username
    MONGODB_ROOT_PASSWORD = local.mongodb_password
    MONGODB_DB            = var.db_name
    MONGODB_URL           = local.mongodb_url
  }
}

resource "kubernetes_config_map_v1" "authdb" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "authdb-config"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.project_name
    }
  }

  data = {
    DB_NAME                     = var.db_name
    USER_RPC_QUEUE              = "user_rpc_queue"
    ALGORITHM                   = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = "30"
  }
}

resource "kubernetes_config_map_v1" "gateway_nginx" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "gateway-nginx-config"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "gateway"
    }
  }

  data = {
    "nginx.conf" = <<-EOT
      pid /tmp/nginx.pid;
      error_log /tmp/nginx-error.log warn;

      events {
          worker_connections 1024;
      }

      http {
          access_log /tmp/nginx-access.log;

          upstream auth_service {
              server auth-service:8001;
          }

          upstream user_service {
              server user-service:8002;
          }

          upstream task_service {
              server task-service:8003;
          }

          server {
              listen 80;
              server_name _;
              client_max_body_size 10m;

              proxy_http_version 1.1;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";

              add_header Access-Control-Allow-Origin "*" always;
              add_header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS" always;
              add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;

              if ($request_method = OPTIONS) {
                  return 204;
              }

              location = /api/v1/health {
                  default_type application/json;
                  return 200 '{"status":"ok","service":"gateway"}';
              }

              location = /api/v1/health/auth {
                  proxy_pass http://auth_service/api/v1/health;
              }

              location = /api/v1/health/users {
                  proxy_pass http://user_service/api/v1/health;
              }

              location = /api/v1/health/tasks {
                  proxy_pass http://task_service/api/v1/health;
              }

              location = /api/v1/auth {
                  proxy_pass http://auth_service;
              }

              location ^~ /api/v1/auth/ {
                  proxy_pass http://auth_service;
              }

              location = /api/v1/users {
                  proxy_pass http://user_service;
              }

              location ^~ /api/v1/users/ {
                  proxy_pass http://user_service;
              }

              location = /api/v1/tasks {
                  proxy_pass http://task_service;
              }

              location ^~ /api/v1/tasks/ {
                  proxy_pass http://task_service;
              }

              location / {
                  default_type application/json;
                  return 404 '{"detail":"Not Found"}';
              }
          }
      }
    EOT
  }
}

resource "kubernetes_persistent_volume_claim_v1" "mongodb_data" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "mongodb-data"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "mongodb"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "mongodb" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "mongodb"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "mongodb"
        }
      }

      spec {
        container {
          name  = "mongodb"
          image = "mongo:7"

          port {
            name           = "mongodb"
            container_port = 27017
          }

          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "MONGODB_ROOT_USER"
              }
            }
          }

          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "MONGODB_ROOT_PASSWORD"
              }
            }
          }

          env {
            name = "MONGO_INITDB_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "MONGODB_DB"
              }
            }
          }

          volume_mount {
            name       = "mongodb-data"
            mount_path = "/data/db"
          }

          readiness_probe {
            exec {
              command = ["mongosh", "--quiet", "--eval", "db.adminCommand(\"ping\")"]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }

          liveness_probe {
            exec {
              command = ["mongosh", "--quiet", "--eval", "db.adminCommand(\"ping\")"]
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 5
          }
        }

        volume {
          name = "mongodb-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mongodb_data[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment_v1" "rabbitmq" {
  count = var.deploy_kubernetes ? 1 : 0

  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.authdb[0].metadata[0].name

    labels = {
      "app.kubernetes.io/name" = "rabbitmq"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "rabbitmq"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3-management"

          port {
            name           = "amqp"
            container_port = 5672
          }

          port {
            name           = "management"
            container_port = 15672
          }

          env {
            name = "RABBITMQ_DEFAULT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "RABBITMQ_DEFAULT_USER"
              }
            }
          }

          env {
            name = "RABBITMQ_DEFAULT_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.authdb[0].metadata[0].name
                key  = "RABBITMQ_DEFAULT_PASS"
              }
            }
          }

          readiness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "ping"]
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            timeout_seconds       = 5
          }

          liveness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "ping"]
            }
            initial_delay_seconds = 40
            period_seconds        = 20
            timeout_seconds       = 5
          }
        }
      }
    }
  }
}

