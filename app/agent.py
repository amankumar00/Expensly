import os
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Initialize the primary LLM (Gemini 1.5 Flash has a massive free tier!)
llm = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash",
    google_api_key=os.getenv("GEMINI_API_KEY"),
    temperature=0.0  # We want deterministic, fact-based extractions
)

def extract_transaction_details(user_input: str):
    """
    Temporary function to test the LLM connection before we add our Pydantic guardrails.
    """
    prompt = ChatPromptTemplate.from_messages([
        ("system", "You are an expert financial assistant. Extract the amount, merchant, date, and category from the following user expense report."),
        ("user", "{input}")
    ])
    
    chain = prompt | llm
    response = chain.invoke({"input": user_input})
    return response.content
