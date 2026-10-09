# Expensly 🚀

Expensly is a modern, AI-powered personal finance and expense tracking SaaS application. It allows users to naturally log their expenses simply by chatting with an AI agent powered by **Gemini 2.5 Flash**, or by manually entering data through a gorgeous, glassmorphic dashboard.

![Dashboard Preview](https://img.shields.io/badge/UI-Glassmorphism-00F2FE?style=for-the-badge) ![Backend](https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge) ![Frontend](https://img.shields.io/badge/Frontend-Flutter-02569B?style=for-the-badge) ![AI](https://img.shields.io/badge/AI-LangChain%20%7C%20Gemini-F9AB00?style=for-the-badge)

## ✨ Key Features

- **🤖 AI-Powered Chat Logging:** Don't want to fill out forms? Just type *"I bought a $5 coffee at Starbucks"* and Expensly's AI agent parses the merchant, amount, category, and date automatically.
- **🛡️ Prompt Injection Guardrails:** Built-in real-time LLM validation layer to detect and block malicious prompt injections into your database.
- **📊 Premium Analytics Dashboard:** A completely custom, staggered-animated dashboard featuring interactive Donut charts and trend-visualizing Bar charts.
- **💱 Real-Time Currency Handling:** Global support. Input expenses in Rupees or Yen; the AI handles conversions seamlessly, stores them neutrally, and returns analytics in your preferred profile currency.
- **🧠 Semantic Vectors (pgvector):** All transactions are embedded into a `pgvector` database to lay the foundation for advanced semantic searching.
- **🔒 Secure Authentication:** Full JWT-based login and signup workflows.

---

## 🛠️ Technology Stack

**Backend:**
- **Python 3.10+**
- **FastAPI** (High-performance API routing)
- **SQLModel & SQLAlchemy** (ORM)
- **PostgreSQL + pgvector** (Relational & Vector Database)
- **LangChain & Google GenAI** (AI Orchestration & LLM)
- **Pytest** (Comprehensive E2E & Unit Testing)

**Frontend:**
- **Flutter Web / Dart**
- **fl_chart** (Beautiful, highly-interactive data visualizations)
- **Glassmorphism UI** (Vibrant neons + frosted glass backdrop blurs)

---

## 🚀 Getting Started

Follow these instructions to get a local copy of Expensly up and running.

### 1. Prerequisites
- **Python 3.10** or higher
- **Flutter SDK** installed and configured for Web (`flutter config --enable-web`)
- **PostgreSQL** running locally with the `pgvector` extension enabled.

### 2. Database Setup
Create a PostgreSQL user and database:
```sql
CREATE DATABASE expensly;
CREATE USER expensly_user WITH ENCRYPTED PASSWORD 'password123';
GRANT ALL PRIVILEGES ON DATABASE expensly TO expensly_user;
```
*Note: Make sure to connect to the `expensly` database and run `CREATE EXTENSION vector;`*

### 3. Backend Setup

1. Clone the repository and navigate to the root directory.
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   # Windows:
   .\venv\Scripts\activate
   # Mac/Linux:
   source venv/bin/activate
   ```
3. Install backend dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file in the root directory based on your environment:
   ```env
   GEMINI_API_KEY="your_google_gemini_api_key"
   DATABASE_URL="postgresql://expensly_user:password123@localhost:5432/expensly"
   SECRET_KEY="a_very_secure_secret_string_for_jwts"
   ```
5. Run the database migrations to build tables and vector columns:
   ```bash
   python migrate.py
   ```
6. Start the FastAPI development server:
   ```bash
   uvicorn app.main:app --reload
   ```
   *The API will be available at `http://127.0.0.1:8000`*

### 4. Frontend Setup

1. Open a new terminal and navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Get the Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the Flutter web app:
   ```bash
   flutter run -d chrome
   ```

---

## 🧪 Testing

Expensly comes with a comprehensive `pytest` suite ensuring AI routing, auth, CRUD, and prompt injection guards are fully functional.

To run the tests, ensure your virtual environment is activated and run:
```bash
python -m pytest tests/ -v
```

---

## 📝 License

Distributed under the MIT License. See `LICENSE` for more information.
