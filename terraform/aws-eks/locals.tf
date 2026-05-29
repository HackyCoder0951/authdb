locals {
  # The user requested m7i-flex.large only. Do not add fallback instance types here.
  eks_node_instance_types = ["m7i-flex.large"]

  common_tags = merge(var.tags, {
    Project     = var.project_name
    ClusterName = var.cluster_name
  })

  mongodb_password = coalesce(var.mongodb_password, random_password.mongodb.result)
  rabbitmq_password = coalesce(var.rabbitmq_password, random_password.rabbitmq.result)
  jwt_secret_key = coalesce(var.jwt_secret_key, random_password.jwt_secret.result)

  mongodb_url = "mongodb://${var.mongodb_username}:${local.mongodb_password}@mongodb:27017/${var.db_name}?authSource=admin"
  rabbitmq_url = "amqp://${var.rabbitmq_username}:${local.rabbitmq_password}@rabbitmq:5672/"
}

