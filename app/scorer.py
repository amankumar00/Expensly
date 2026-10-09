from datetime import date
from app.models import Transaction

def calculate_confidence_score(transaction: Transaction) -> float:
    """
    Deterministically scores the LLM's extraction based on strict business rules.
    Returns a float between 0.0 (terrible) and 1.0 (perfect).
    """
    score = 1.0
    
    # Rule 1: The amount must be a positive number
    if transaction.amount <= 0:
        score -= 0.5
        
    # Rule 2: We must have a recognizable merchant name
    if not transaction.merchant or len(transaction.merchant) < 2 or transaction.merchant.lower() in ["unknown", "n/a", "none"]:
        score -= 0.4
        
    # Rule 3: Date cannot be in the future
    if transaction.date > date.today():
        score -= 0.3
        
    # Rule 4: Category must be concise (not a whole sentence from the LLM)
    if len(transaction.category.split()) > 3:
        score -= 0.2
        
    # Cap the minimum score at 0.0
    return max(0.0, round(score, 2))
