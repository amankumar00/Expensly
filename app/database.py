from sqlmodel import SQLModel, create_engine, Session
from sqlalchemy import text

# Database connection URL (User: postgres, Password: password, DB: expensly)
DATABASE_URL = "postgresql+psycopg2://postgres:password@localhost:5433/expensly"

# Create the SQLAlchemy engine
engine = create_engine(DATABASE_URL, echo=True)

def create_db_and_tables():
    """Create all tables defined by SQLModel."""
    with engine.connect() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        conn.commit()
    SQLModel.metadata.create_all(engine)

def get_session():
    """Dependency to provide a database session to our endpoints."""
    with Session(engine) as session:
        yield session
