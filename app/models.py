from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from sqlalchemy import Column
from pgvector.sqlalchemy import Vector
import datetime

class User(SQLModel, table=True):
    __tablename__ = "users"
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(unique=True, index=True)
    hashed_password: str
    name: str
    currency: str = Field(default="USD")

class ChatMessageRecord(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    text: str
    is_user: bool
    timestamp: datetime.datetime = Field(default_factory=lambda: datetime.datetime.now(datetime.timezone.utc))


class FinancialDocument(SQLModel, table=True):
    """
    Stores financial advice documents and their vector embeddings for RAG.
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    content: str = Field(description="The text content of the financial document")
    embedding: List[float] = Field(sa_column=Column(Vector(3072))) # Gemini embeddings use 3072 dimensions

class Transaction(SQLModel, table=True):
    """
    Database model and Pydantic schema for an extracted expense transaction.
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    original_text: str = Field(description="The exact text the user sent")
    amount: float = Field(description="The numeric amount spent")
    merchant: str = Field(description="The name of the store, service, or person paid")
    category: str = Field(description="Categorization of the expense (e.g., Food, Travel, Utilities)")
    date: datetime.date = Field(description="The date the transaction occurred")
    confidence_score: Optional[float] = Field(default=1.0, description="AI confidence in extraction (0.0 to 1.0)")
    embedding: Optional[List[float]] = Field(default=None, sa_column=Column(Vector(3072)))
