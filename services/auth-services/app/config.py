from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "auth_service"
    MONGODB_URL: str = "mongodb://localhost:27017"
    DB_NAME: str = "auth_scaleDB"
    SECRET_KEY: str = "supersecretkey"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    RABBITMQ_URL: str = "amqp://guest:guest@localhost/"

    model_config = SettingsConfigDict(
        env_file=[".env", "../../.env"],
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
