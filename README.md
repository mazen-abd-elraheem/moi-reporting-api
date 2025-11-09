# MoI Digital Reporting System - Squad Alpha Deployment Guide

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Azure Resources Setup](#azure-resources-setup)
3. [Database Deployment](#database-deployment)
4. [FastAPI Application Setup](#fastapi-application-setup)
5. [Testing & Verification](#testing--verification)
6. [Next Steps](#next-steps)

---

## Prerequisites

### Required Tools
- **Azure CLI** (`az`) - [Install Guide](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **Python 3.11+** - [Download](https://www.python.org/downloads/)
- **Git** - Version control
- **Docker** (optional) - For containerized deployment
- **SQL Server Management Studio** or **Azure Data Studio** - For database management

### Required Access
- Azure Subscription with Contributor role
- Resource Group: `rg-moi-reporting-prod`
- Permissions to create Key Vault, SQL Database, and App Service

---

## Azure Resources Setup

### 1. Login to Azure
```bash
# Login to Azure
az login

# Set default subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Set default resource group
az configure --defaults group=rg-moi-reporting-prod location=eastus
```

### 2. Create Resource Group (if not exists)
```bash
az group create \
  --name rg-moi-reporting-prod \
  --location eastus
```

### 3. Create Azure Key Vault
```bash
# Create Key Vault
az keyvault create \
  --name moi-reporting-kv \
  --resource-group rg-moi-reporting-prod \
  --location eastus \
  --enable-rbac-authorization false

# Get your user's Object ID
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Grant yourself Key Vault Secrets Officer role
az keyvault set-policy \
  --name moi-reporting-kv \
  --object-id $USER_OBJECT_ID \
  --secret-permissions get list set delete
```

### 4. Create Azure SQL Server & Database
```bash
# Create SQL Server
az sql server create \
  --name moi-reporting-sql \
  --resource-group rg-moi-reporting-prod \
  --location eastus \
  --admin-user sqladmin \
  --admin-password "YourSecurePassword123!"

# Configure firewall (allow Azure services)
az sql server firewall-rule create \
  --resource-group rg-moi-reporting-prod \
  --server moi-reporting-sql \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Add your IP for development access
YOUR_IP=$(curl -s ifconfig.me)
az sql server firewall-rule create \
  --resource-group rg-moi-reporting-prod \
  --server moi-reporting-sql \
  --name AllowMyIP \
  --start-ip-address $YOUR_IP \
  --end-ip-address $YOUR_IP

# Create database
az sql db create \
  --resource-group rg-moi-reporting-prod \
  --server moi-reporting-sql \
  --name MoI_Reporting_DB \
  --service-objective S2 \
  --backup-storage-redundancy Local
```

### 5. Create Azure Blob Storage
```bash
# Create storage account
az storage account create \
  --name moireportingstorage \
  --resource-group rg-moi-reporting-prod \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2

# Create container for attachments
az storage container create \
  --name report-attachments \
  --account-name moireportingstorage \
  --public-access off
```

### 6. Store Secrets in Key Vault
```bash
# Database connection string
DB_CONNECTION_STRING="Driver={ODBC Driver 18 for SQL Server};Server=tcp:moi-reporting-sql.database.windows.net,1433;Database=MoI_Reporting_DB;Uid=sqladmin;Pwd=YourSecurePassword123!;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"

az keyvault secret set \
  --vault-name moi-reporting-kv \
  --name database-connection-string \
  --value "$DB_CONNECTION_STRING"

# Blob storage connection string
BLOB_CONNECTION_STRING=$(az storage account show-connection-string \
  --name moireportingstorage \
  --resource-group rg-moi-reporting-prod \
  --query connectionString -o tsv)

az keyvault secret set \
  --vault-name moi-reporting-kv \
  --name blob-storage-connection-string \
  --value "$BLOB_CONNECTION_STRING"

# JWT Secret Key (generate random secure key)
JWT_SECRET=$(openssl rand -base64 32)
az keyvault secret set \
  --vault-name moi-reporting-kv \
  --name jwt-secret-key \
  --value "$JWT_SECRET"
```

### 7. Create Service Principal for Application
```bash
# Create service principal
az ad sp create-for-rbac \
  --name moi-reporting-api-sp \
  --role "Key Vault Secrets User" \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-moi-reporting-prod/providers/Microsoft.KeyVault/vaults/moi-reporting-kv

# Save the output:
# {
#   "appId": "YOUR_CLIENT_ID",
#   "password": "YOUR_CLIENT_SECRET",
#   "tenant": "YOUR_TENANT_ID"
# }
```

---

## Database Deployment

### 1. Connect to Azure SQL Database

**Using Azure Data Studio:**
1. Open Azure Data Studio
2. New Connection
   - Server: `moi-reporting-sql.database.windows.net`
   - Authentication: SQL Login
   - User: `sqladmin`
   - Password: `YourSecurePassword123!`
   - Database: `MoI_Reporting_DB`

**Using SQLCMD:**
```bash
sqlcmd -S moi-reporting-sql.database.windows.net \
  -d MoI_Reporting_DB \
  -U sqladmin \
  -P "YourSecurePassword123!" \
  -i schema.sql
```

### 2. Execute Schema Script
Copy the entire SQL schema script from the artifact and execute it in your SQL client.

### 3. Verify Database Setup
```sql
-- Check tables
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- Check indexes
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE t.name IN ('User', 'Report', 'Attachment')
ORDER BY t.name;

-- View sample data
SELECT * FROM [dbo].[User];
SELECT * FROM [dbo].[Report];
SELECT * FROM [dbo].[vw_ReportSummary];
```

---

## FastAPI Application Setup

### 1. Clone/Create Project Structure
```bash
# Create project directory
mkdir moi-reporting-api
cd moi-reporting-api

# Create directory structure
mkdir -p app/{core,models,schemas,api/v1,services}
mkdir tests

# Initialize git
git init
```

### 2. Create Virtual Environment
```bash
# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (Linux/Mac)
source venv/bin/activate
```

### 3. Install Dependencies
```bash
# Create requirements.txt (use content from FastAPI artifact)
cat > requirements.txt << EOF
fastapi==0.109.0
uvicorn[standard]==0.27.0
sqlalchemy==2.0.25
pyodbc==5.0.1
pydantic==2.5.3
pydantic-settings==2.1.0
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
azure-identity==1.15.0
azure-keyvault-secrets==4.7.0
azure-storage-blob==12.19.0
python-dotenv==1.0.0
EOF

# Install dependencies
pip install -r requirements.txt
```

### 4. Create Configuration Files

**Create `.env` file:**
```bash
cat > .env << EOF
AZURE_KEY_VAULT_NAME=moi-reporting-kv
AZURE_TENANT_ID=YOUR_TENANT_ID
AZURE_CLIENT_ID=YOUR_CLIENT_ID
AZURE_CLIENT_SECRET=YOUR_CLIENT_SECRET
ENVIRONMENT=development
API_VERSION=v1
DEBUG=True
EOF
```

**Create `.gitignore`:**
```bash
cat > .gitignore << EOF
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/

# Environment
.env
.env.local

# IDE
.vscode/
.idea/
*.swp

# Testing
.pytest_cache/
htmlcov/
.coverage

# Database
*.db
*.sqlite
EOF
```

### 5. Copy Application Code
Copy all the code from the FastAPI artifact into the respective files:
- `app/core/config.py`
- `app/core/database.py`
- `app/models/user.py`
- `app/models/report.py`
- `app/models/attachment.py`
- `app/main.py`
- `app/__init__.py`

### 6. Run the Application Locally
```bash
# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Server will start at: http://localhost:8000
# API Docs available at: http://localhost:8000/api/docs
```

### 7. Test Health Check
```bash
# Test health endpoint
curl http://localhost:8000/health

# Expected response:
# {
#   "status": "healthy",
#   "service": "MoI Digital Reporting System",
#   "version": "v1",
#   "environment": "development"
# }
```

---

## Testing & Verification

### 1. Database Connection Test
Create `tests/test_database.py`:
```python
from app.core.database import engine
from sqlalchemy import text

def test_database_connection():
    """Test database connection"""
    with engine.connect() as conn:
        result = conn.execute(text("SELECT 1 AS test"))
        assert result.fetchone()[0] == 1
        print("✓ Database connection successful")

def test_tables_exist():
    """Test that all required tables exist"""
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT TABLE_NAME 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_TYPE = 'BASE TABLE'
            AND TABLE_NAME IN ('User', 'Report', 'Attachment')
        """))
        tables = [row[0] for row in result]
        assert len(tables) == 3
        print(f"✓ All tables exist: {tables}")

if __name__ == "__main__":
    test_database_connection()
    test_tables_exist()
```

Run tests:
```bash
python tests/test_database.py
```

### 2. Key Vault Connection Test
```python
from app.core.config import get_settings

def test_key_vault():
    """Test Key Vault connection"""
    settings = get_settings()
    assert settings.DATABASE_CONNECTION_STRING is not None
    assert settings.BLOB_STORAGE_CONNECTION_STRING is not None
    print("✓ Key Vault secrets loaded successfully")

if __name__ == "__main__":
    test_key_vault()
```

### 3. API Integration Test
```bash
# Install pytest
pip install pytest pytest-asyncio httpx

# Create test file
cat > tests/test_api.py << 'EOF'
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    print("✓ Health check passed")

def test_root_endpoint():
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()
    print("✓ Root endpoint passed")

if __name__ == "__main__":
    test_health_check()
    test_root_endpoint()
EOF

# Run tests
pytest tests/test_api.py -v
```

---

## Next Steps

### Phase 2 Tasks (Coming Soon)

#### Squad Alpha - API & Ingestion:
1. ✅ **Build the FastAPI App** - COMPLETED
2. ✅ **Implement Core Schemas** - COMPLETED
3. **Build POST /reports Endpoint** - Next task
   - Create Pydantic schemas for request/response
   - Implement report creation logic
   - Add validation and error handling
   - Test with sample data

#### Squad Bravo - Platform & Analytics:
1. **Set up Analytics DB**
   - Create read-optimized schema
   - Add denormalized views
   - Implement columnstore indexes
   
2. **Build "V1" ETL Pipeline**
   - Create Azure Data Factory workspace
   - Configure linked services
   - Build copy pipeline (15-min schedule)
   - Test data synchronization

3. **Build Admin Read API (V1)**
   - Create GET /admin/reports endpoint
   - Connect to analytics database
   - Add filtering and pagination
   - Implement caching strategy

### Immediate Action Items

1. **Review and validate the schema**
   ```sql
   -- Run this in your SQL client
   EXEC sp_help 'User';
   EXEC sp_help 'Report';
   EXEC sp_help 'Attachment';
   ```

2. **Test the FastAPI application**
   ```bash
   # Ensure all tests pass
   python tests/test_database.py
   python tests/test_api.py
   pytest -v
   ```

3. **Set up monitoring**
   - Enable Application Insights
   - Configure database alerts
   - Set up log analytics

4. **Document any issues**
   - Connection problems
   - Missing permissions
   - Configuration errors

---

## Troubleshooting

### Common Issues

**1. Database Connection Fails**
```bash
# Check firewall rules
az sql server firewall-rule list \
  --resource-group rg-moi-reporting-prod \
  --server moi-reporting-sql

# Verify connection string
az keyvault secret show \
  --vault-name moi-reporting-kv \
  --name database-connection-string
```

**2. Key Vault Access Denied**
```bash
# Check access policies
az keyvault show \
  --name moi-reporting-kv \
  --query properties.accessPolicies

# Grant access if needed
az keyvault set-policy \
  --name moi-reporting-kv \
  --object-id YOUR_OBJECT_ID \
  --secret-permissions get list
```

**3. ODBC Driver Not Found**
```bash
# Windows - Download from Microsoft
# https://docs.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server

# Linux (Ubuntu/Debian)
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18
```

---

## Support & Resources

- **Azure Documentation**: https://docs.microsoft.com/azure/
- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **SQLAlchemy Documentation**: https://docs.sqlalchemy.org/
- **Project Repository**: [Your Git Repo URL]

---

## Completion Checklist

### Squad Alpha Tasks
- [x] Azure resources created (Key Vault, SQL, Blob Storage)
- [x] Database schema deployed
- [x] Sample data inserted
- [x] FastAPI application structure created
- [x] Key Vault integration implemented
- [x] Database models created
- [x] Application runs locally
- [x] Health check endpoint works
- [x] Basic tests pass

### Ready for Phase 2
- [ ] POST /reports endpoint implemented
- [ ] File upload functionality working
- [ ] Voice-to-text integration ready
- [ ] API documentation complete

---

**Last Updated**: November 9, 2025  
**Version**: 1.0.0  
**Status**: Phase 1 Complete ✅