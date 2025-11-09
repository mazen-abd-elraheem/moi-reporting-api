# ============= Project Structure =============
"""
moi-reporting-api/
│
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI application entry point
│   │
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py          # Settings & Key Vault integration
│   │   ├── database.py        # Database connection & session
│   │   └── security.py        # Authentication utilities (future)
│   │
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py            # User SQLAlchemy model
│   │   ├── report.py          # Report SQLAlchemy model
│   │   └── attachment.py      # Attachment SQLAlchemy model
│   │
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py            # User Pydantic schemas (next phase)
│   │   ├── report.py          # Report Pydantic schemas (next phase)
│   │   └── attachment.py      # Attachment Pydantic schemas (next phase)
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── reports.py     # Report endpoints (next phase)
│   │       ├── users.py       # User endpoints (next phase)
│   │       └── auth.py        # Auth endpoints (next phase)
│   │
│   └── services/
│       ├── __init__.py
│       ├── report_service.py  # Business logic (next phase)
│       └── blob_service.py    # Azure Blob operations (next phase)
│
├── tests/
│   ├── __init__.py
│   └── test_api.py
│
├── .env.example
├── .gitignore
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── README.md
"""