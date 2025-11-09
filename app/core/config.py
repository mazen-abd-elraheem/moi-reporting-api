from pydantic_settings import BaseSettings
from functools import lru_cache
from azure.identity import DefaultAzureCredential, ClientSecretCredential
from azure.keyvault.secrets import SecretClient
import os
from typing import Optional


class Settings(BaseSettings):
    """Application settings with Azure Key Vault integration"""
    
    # App Configuration
    APP_NAME: str = "MoI Digital Reporting System"
    API_VERSION: str = "v1"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    
    # Azure Key Vault
    AZURE_KEY_VAULT_NAME: str
    AZURE_TENANT_ID: Optional[str] = None
    AZURE_CLIENT_ID: Optional[str] = None
    AZURE_CLIENT_SECRET: Optional[str] = None
    
    # Database (loaded from Key Vault)
    DATABASE_CONNECTION_STRING: Optional[str] = None
    
    # Blob Storage (loaded from Key Vault)
    BLOB_STORAGE_CONNECTION_STRING: Optional[str] = None
    BLOB_CONTAINER_NAME: str = "report-attachments"
    
    # Security
    SECRET_KEY: Optional[str] = None
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # CORS
    ALLOWED_ORIGINS: list = ["http://localhost:3000", "http://localhost:8080"]
    
    # API Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    
    class Config:
        env_file = ".env"
        case_sensitive = True


class AzureKeyVaultManager:
    """Manages Azure Key Vault connections and secret retrieval"""
    
    def __init__(self, settings: Settings):
        self.settings = settings
        self.key_vault_url = f"https://{settings.AZURE_KEY_VAULT_NAME}.vault.azure.net/"
        self.credential = self._get_credential()
        self.secret_client = SecretClient(
            vault_url=self.key_vault_url,
            credential=self.credential
        )
    
    def _get_credential(self):
        """Get Azure credential based on environment"""
        if self.settings.ENVIRONMENT == "development":
            # Use service principal for development
            if all([
                self.settings.AZURE_TENANT_ID,
                self.settings.AZURE_CLIENT_ID,
                self.settings.AZURE_CLIENT_SECRET
            ]):
                return ClientSecretCredential(
                    tenant_id=self.settings.AZURE_TENANT_ID,
                    client_id=self.settings.AZURE_CLIENT_ID,
                    client_secret=self.settings.AZURE_CLIENT_SECRET
                )
        
        # Use DefaultAzureCredential for production (Managed Identity)
        return DefaultAzureCredential()
    
    def get_secret(self, secret_name: str) -> str:
        """Retrieve a secret from Azure Key Vault"""
        try:
            secret = self.secret_client.get_secret(secret_name)
            return secret.value
        except Exception as e:
            print(f"Error retrieving secret '{secret_name}': {str(e)}")
            raise
    
    def load_secrets_to_settings(self, settings: Settings) -> Settings:
        """Load all required secrets from Key Vault into settings"""
        secrets_mapping = {
            "database-connection-string": "DATABASE_CONNECTION_STRING",
            "blob-storage-connection-string": "BLOB_STORAGE_CONNECTION_STRING",
            "jwt-secret-key": "SECRET_KEY",
        }
        
        for secret_name, setting_name in secrets_mapping.items():
            try:
                secret_value = self.get_secret(secret_name)
                setattr(settings, setting_name, secret_value)
                print(f"✓ Loaded secret: {secret_name}")
            except Exception as e:
                print(f"✗ Failed to load secret '{secret_name}': {str(e)}")
                if self.settings.ENVIRONMENT == "production":
                    raise
        
        return settings


@lru_cache()
def get_settings() -> Settings:
    """Get application settings (cached)"""
    settings = Settings()
    
    # Load secrets from Key Vault if not in local development mode
    if settings.DATABASE_CONNECTION_STRING is None:
        kv_manager = AzureKeyVaultManager(settings)
        settings = kv_manager.load_secrets_to_settings(settings)
    
    return settings