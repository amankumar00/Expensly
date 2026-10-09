from langchain_core.tools import tool
from sqlmodel import Session
from app.agent import llm
from app.models import Transaction
from app.scorer import calculate_confidence_score
from app.database import engine
from langchain_google_genai import GoogleGenerativeAIEmbeddings
import os

# Initialize the Gemini Embeddings model
embeddings_model = GoogleGenerativeAIEmbeddings(model="models/gemini-embedding-2", google_api_key=os.getenv("GEMINI_API_KEY"))

from pydantic import BaseModel
from datetime import date
from typing import Literal
from app.main import EXCHANGE_RATES
from app.models import User

# Predefined categories for strict LLM constraint
CategoryType = Literal[
    "Food & Dining", "Transportation", "Utilities", "Housing", "Entertainment", 
    "Shopping", "Groceries", "Healthcare", "Education", "Personal Care", 
    "Travel", "Debt", "Gifts & Donations", "Investments", "Income", "Misc"
]

class TransactionExtraction(BaseModel):
    amount: float
    currency_code: str
    merchant: str
    category: CategoryType
    date: date
    original_text: str

# 1. Bind our LLM so it strictly outputs our extraction schema
structured_extractor = llm.with_structured_output(TransactionExtraction)

def get_log_expense_tool(user_id: int):
    @tool
    def log_expense_tool(expense_report: str) -> str:
        """
        Use this tool to log a new expense into the database. 
        Pass the user's raw natural language expense report as the input.
        """
        try:
            extraction = structured_extractor.invoke(expense_report)
        except Exception as e:
            return f"Failed to extract transaction details: {str(e)}"
            
        with Session(engine) as session:
            user = session.get(User, user_id)
            user_currency = user.currency if user else "USD"
            
            # If the LLM didn't specify a currency, default to the user's preferred currency
            currency_code = extraction.currency_code if extraction.currency_code else user_currency
            
            # Convert to USD for neutral database storage
            rate = EXCHANGE_RATES.get(currency_code.upper(), 1.0)
            amount_in_usd = extraction.amount / rate
            
            transaction = Transaction(
                user_id=user_id,
                original_text=extraction.original_text,
                amount=amount_in_usd,
                merchant=extraction.merchant,
                category=extraction.category,
                date=extraction.date,
            )
            
            confidence_score = calculate_confidence_score(transaction)
            transaction.confidence_score = confidence_score
            
            if confidence_score < 0.6:
                return f"Confidence score too low ({confidence_score}). Ask the user for clarification about the merchant, amount, or category."
                
            session.add(transaction)
            session.commit()
            session.refresh(transaction)
            
        return f"Successfully logged expense! ID: {transaction.id}, Merchant: {transaction.merchant}, Amount in USD: ${transaction.amount:.2f}, Category: {transaction.category}"
    return log_expense_tool

def get_query_transactions_sql_tool(user_id: int):
    @tool
    def query_transactions_sql_tool(sql_query: str) -> str:
        """
        Executes a raw SQL query against the 'transaction' table to analyze past expenses.
        The table has columns: id, original_text, amount, merchant, category, date, confidence_score.
        Use this tool when the user asks analytics questions (e.g., 'how much did I spend on food?').
        """
        if any(forbidden in sql_query.upper() for forbidden in ["DROP", "DELETE", "UPDATE", "INSERT", "ALTER"]):
            return "Security Guardrail Blocked: Only SELECT queries are permitted for analytics."
            
        try:
            from sqlalchemy import text
            with Session(engine) as session:
                user = session.get(User, user_id)
                user_currency = user.currency if user else "USD"
                rate = EXCHANGE_RATES.get(user_currency.upper(), 1.0)
                
                # SECURE MULTI-TENANCY: Wrap their query using a CTE so they only query their records.
                secure_query = f"WITH transaction AS (SELECT * FROM transaction WHERE user_id = {user_id}) {sql_query}"
                
                result = session.execute(text(secure_query))
                rows = result.fetchall()
                
                # Multiply numerical columns (amounts) by rate to provide results in user's currency
                converted_rows = []
                for row in rows:
                    converted_row = []
                    for val in row:
                        if isinstance(val, (int, float)):
                            converted_row.append(round(val * rate, 2))
                        else:
                            converted_row.append(val)
                    converted_rows.append(tuple(converted_row))
                    
                return f"Query Results (in {user_currency}): {converted_rows}"
        except Exception as e:
            return f"SQL Execution Error: {str(e)}"
    return query_transactions_sql_tool

def get_rag_financial_knowledge_tool():
    @tool
    def rag_financial_knowledge_tool(query: str) -> str:
        """
        Searches the RAG vector database for financial advice or policies related to the user's query.
        Use this when the user asks for financial tips, budget rules, or advice (e.g., 'how much should I save?').
        """
        try:
            query_vector = embeddings_model.embed_query(query)
            with Session(engine) as session:
                from app.models import FinancialDocument
                results = session.query(FinancialDocument).order_by(
                    FinancialDocument.embedding.l2_distance(query_vector)
                ).limit(2).all()
                
                if not results:
                    return "No relevant financial advice found in the knowledge base."
                    
                return "Found these relevant financial rules in the knowledge base:\n" + "\n".join([f"- {doc.content}" for doc in results])
        except Exception as e:
            return f"RAG Search Error: {str(e)}"
    return rag_financial_knowledge_tool
