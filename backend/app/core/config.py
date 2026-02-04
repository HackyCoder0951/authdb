from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "auth_scale"
    MONGODB_URL: str = "mongodb://user_authDB:auth245005db@cluster0.pyl0utg.mongodb.net/?appName=Cluster0" # Non-TLS connection
    DB_NAME: str = "auth_scaleDB"
    SECRET_KEY: str = "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7" # Change in production
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    class Config:
        case_sensitive = True

settings = Settings()
