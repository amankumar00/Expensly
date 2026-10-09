from sqlmodel import Session
from app.database import engine
from app.models import FinancialDocument
from app.tools import embeddings_model

def seed_database():
    docs = [
        "The 50/30/20 rule: Allocate 50% of your income to needs, 30% to wants, and 20% to savings.",
        "Always pay off high-interest credit card debt before investing in stocks.",
        "An emergency fund should cover 3 to 6 months of living expenses."
    ]
    
    with Session(engine) as session:
        # Check if already seeded
        existing = session.query(FinancialDocument).first()
        if existing:
            print("Database already seeded!")
            return
            
        print("Embedding documents into mathematical vectors... this takes a second.")
        for doc in docs:
            # We call Gemini to turn the sentence into a 768-dimensional float array
            embedding = embeddings_model.embed_query(doc)
            db_doc = FinancialDocument(content=doc, embedding=embedding)
            session.add(db_doc)
            
        session.commit()
        print("Successfully seeded financial knowledge base!")

if __name__ == "__main__":
    seed_database()
