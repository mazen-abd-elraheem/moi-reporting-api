┌─────────────┐
│   Client    │
│  (Flutter)  │
└──────┬──────┘
       │ HTTP Request
       ↓
┌─────────────────────────────────────────┐
│  FastAPI Application (app/main.py)      │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │  API Layer (app/api/v1/)        │    │
│  │  - Routing                      │    │
│  │  - Request/Response handling    │    │
│  └──────────┬──────────────────────┘    │
│             ↓                           │
│  ┌─────────────────────────────────┐    │
│  │  Schemas (app/schemas/)         │    │
│  │  - Pydantic validation          │    │
│  │  - Data transformation          │    │
│  └──────────┬──────────────────────┘    │
│             ↓                           │
│  ┌─────────────────────────────────┐    │
│  │  Services (app/services/)       │    │
│  │  - Business logic               │    │
│  │  - External API calls           │    │
│  └──────────┬──────────────────────┘    │
│             ↓                           │
│  ┌─────────────────────────────────┐    │
│  │  Models (app/models/)           │    │
│  │  - SQLAlchemy ORM               │    │
│  │  - Database operations          │    │
│  └──────────┬──────────────────────┘    │
└─────────────┼───────────────────────────┘
              ↓
   ┌──────────────────────┐
   │  Azure SQL Database  │
   │  - User table        │
   │  - Report table      │
   │  - Attachment table  │
   └──────────────────────┘

   ┌──────────────────────┐
   │  Azure Blob Storage  │
   │  - Images            │
   │  - Videos            │
   │  - Audio files       │
   └──────────────────────┘

   ┌──────────────────────┐
   │  Azure Services      │
   │  - Key Vault         │
   │  - Speech Service    │
   │  - ML Service        │
   └──────────────────────┘
