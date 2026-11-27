FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (cached layer — only rebuilds if requirements.txt changes)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all app files
COPY streamlit_app.py .
COPY streamlit_app_tfidf.py .
COPY main.py .

# Copy the company documents the RAG system searches through
COPY _data/ ./_data/

# Use lightweight TF-IDF retrieval for memory-constrained hosting.
# Run streamlit_app.py directly for semantic ChromaDB retrieval locally.
CMD ["streamlit", "run", "streamlit_app_tfidf.py", "--server.port=10000", "--server.address=0.0.0.0"]
