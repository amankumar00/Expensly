from sqlalchemy import text
from app.models import SQLModel
from app.database import engine

def run_migration():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE transaction ADD COLUMN embedding vector(3072)"))
            print("Added embedding column to transaction.")
        except Exception as e:
            print(f"Error altering transaction table: {e}")
        conn.commit()
    SQLModel.metadata.create_all(engine)
    print("Database sync complete.")

if __name__ == "__main__":
    run_migration()
