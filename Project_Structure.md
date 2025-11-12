MOI-REPORTING-API/
│
├── 📁 app/                           # Main application package
│   ├── __init__.py                   # App initialization
│   ├── main.py                       # FastAPI entry point (M marker)
│   │
│   ├── 📁 api/                       # API layer (HTTP endpoints)
│   │   ├── __init__.py
│   │   └── 📁 v1/                    # API version 1
│   │       ├── __init__.py
│   │       ├── auth.py               # Authentication endpoints
│   │       ├── reports.py            # Report CRUD endpoints
│   │       └── users.py              # User management endpoints
│   │
│   ├── 📁 core/                      # Core configuration
│   │   ├── __init__.py
│   │   ├── config.py                 # Settings & Key Vault integration
│   │   ├── database.py               # Database connection & session
│   │   └── security.py               # Auth utilities (JWT, hashing)
│   │
│   ├── 📁 models/                    # Database models (SQLAlchemy ORM)
│   │   ├── __init__.py
│   │   ├── user.py                   # User table model
│   │   ├── report.py                 # Report table model
│   │   └── attachment.py             # Attachment table model
│   │
│   ├── 📁 schemas/                   # Pydantic schemas (validation)
│   │   ├── __init__.py
│   │   ├── user.py                   # User request/response schemas
│   │   ├── report.py                 # Report request/response schemas
│   │   └── attachment.py             # Attachment schemas
│   │
│   └── 📁 services/                  # Business logic layer
│       ├── __init__.py
│       ├── report_service.py         # Report business logic
│       ├── user_service.py           # User business logic
│       ├── blob_service.py           # Azure Blob Storage operations
│       └── ai_service.py             # AI categorization service
│
├── 📁 database/                      # Database management
│   ├── 📁 docs/                      # Database documentation
│   │
│   ├── 📁 migrations/                # Database version control
│   │   ├── versions/                 # Migration files
│   │   ├── env.py                    # Alembic environment
│   │   └── script.py.mako            # Migration template
│   │
│   └── 📁 scripts/                   # SQL scripts
│       ├── schema.sql                # Complete database schema
│       ├── seed_data.sql             # Sample/test data
│       └── test_queries.sql          # Verification queries
│
├── 📁 tests/                         # Test suite
│   ├── __init__.py
│   ├── conftest.py                   # Pytest configuration
│   ├── test_api.py                   # API endpoint tests
│   ├── test_database.py              # Database tests
│   └── test_services.py              # Service layer tests
│
├── 📄 .env.example                   # Environment variables template
├── 📄 .gitignore                     # Git ignore rules
├── 📄 docker-compose.yml             # Multi-container configuration
├── 📄 Dockerfile                     # Container definition
├── 📄 LICENSE                        # Project license
├── 📄 Project_Structure.md           # This file (M marker)
├── 📄 README.md                      # Project documentation (M marker)
└── 📄 requirements.txt               # Python dependencies