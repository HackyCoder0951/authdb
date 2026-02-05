from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "auth_scale"
    MONGODB_URL: str
    DB_NAME: str = "auth_scaleDB"
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    model_config = SettingsConfigDict(
        case_sensitive=True,
        env_file=[".env", "../.env"],
        env_ignore_empty=True,
        extra="ignore"
    )

settings = Settings()
