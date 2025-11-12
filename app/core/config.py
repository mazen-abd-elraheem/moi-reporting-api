from pydantic_settings import BaseSettings
from functools import lru_cache
from azure.identity import DefaultAzureCredential, ClientSecretCredential
from azure.keyvault.secrets import SecretClient
import os
import logging
from typing import Optional

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    APP_NAME: str = "MoI Digital Reporting System"
    API_VERSION: str = "v1"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    # Azure Key Vault
    AZURE_KEY_VAULT_NAME: str
    AZURE_TENANT_ID: Optional[str] = None
    AZURE_CLIENT_ID: Optional[str] = None
    AZURE_CLIENT_SECRET: Optional[str] = None
    
    # Secrets (loaded from Key Vault)
    DATABASE_CONNECTION_STRING: Optional[str] = None
    BLOB_STORAGE_CONNECTION_STRING: Optional[str] = None
    SECRET_KEY: Optional[str] = None
    
    # Static config
    BLOB_CONTAINER_NAME: str = "report-attachments"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ALLOWED_ORIGINS: list = ["http://localhost:3000", "http://localhost:8080", "capacitor://localhost"]
    RATE_LIMIT_PER_MINUTE: int = 60

    class Config:
        case_sensitive = True
        env_file = ".env" if os.getenv("ENVIRONMENT", "development") == "development" else None


class AzureKeyVaultManager:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.key_vault_url = f"https://{settings.AZURE_KEY_VAULT_NAME}.vault.azure.net/"
        self.credential = self._get_credential()
        self.secret_client = SecretClient(vault_url=self.key_vault_url, credential=self.credential)
    
    def _get_credential(self):
        if self.settings.ENVIRONMENT == "development":
            if all([self.settings.AZURE_TENANT_ID, self.settings.AZURE_CLIENT_ID, self.settings.AZURE_CLIENT_SECRET]):
                return ClientSecretCredential(
                    tenant_id=self.settings.AZURE_TENANT_ID,
                    client_id=self.settings.AZURE_CLIENT_ID,
                    client_secret=self.settings.AZURE_CLIENT_SECRET
                )
        return DefaultAzureCredential()

    def get_secret(self, secret_name: str) -> str:
        try:
            secret = self.secret_client.get_secret(secret_name)
            return secret.value
        except Exception as e:
            logger.error(f"Error retrieving secret '{secret_name}': {e}")
            raise

    def load_secrets_to_settings(self, settings: Settings) -> Settings:
        secrets_mapping = {
            "database-connection-string": "DATABASE_CONNECTION_STRING",
            "blob-storage-connection-string": "BLOB_STORAGE_CONNECTION_STRING",
            "jwt-secret-key": "SECRET_KEY",
        }

        for secret_name, setting_name in secrets_mapping.items():
            try:
                value = self.get_secret(secret_name)
                setattr(settings, setting_name, value)
                logger.info(f"✓ Loaded secret: {secret_name}")
            except Exception as e:
                logger.error(f"✗ Failed to load secret '{secret_name}': {e}")
                # Fail fast in production
                if settings.ENVIRONMENT == "production":
                    raise RuntimeError(f"Critical secret '{secret_name}' missing in production")
        return settings


@lru_cache()
def get_settings() -> Settings:
    settings = Settings()
    # Only load from Key Vault if secrets are not already set (e.g., via env vars in prod)
    if settings.DATABASE_CONNECTION_STRING is None:
        kv_manager = AzureKeyVaultManager(settings)
        settings = kv_manager.load_secrets_to_settings(settings)
    return settings