import os

SERVICE_NAME = os.getenv("SERVICE_NAME", "task-service")
TASK_SERVICE_PORT = int(os.getenv("TASK_SERVICE_PORT", "8003"))
USER_RPC_QUEUE = os.getenv("USER_RPC_QUEUE", "user_rpc_queue")
