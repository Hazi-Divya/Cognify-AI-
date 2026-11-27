# Cognify AI

Cognify AI is a Retrieval-Augmented Generation (RAG) chatbot for company knowledge. It searches local `.txt` documents and uses a Groq-hosted language model to produce answers grounded in that content.

The repository provides two interfaces:

- A Streamlit chat application with conversation history and source inspection.
- A FastAPI JSON API for clients, integrations, and custom frontends.

## Supported knowledge

The documents in [`_data/`](_data/) cover:

- Company HR policies
- Engineering standards
- Employee onboarding
- Product knowledge
- Security policies

## Features

- Retrieval from local company documents
- Paragraph-level document chunking
- Semantic search with ChromaDB or lightweight TF-IDF search
- Groq/OpenAI-compatible chat completions
- Source filenames displayed with every answer
- Retrieved chunks available for inspection
- FastAPI Swagger and ReDoc documentation
- Docker support

## Project structure

```text
.
├── main.py                     # FastAPI backend
├── streamlit_app.py            # Streamlit UI using ChromaDB
├── streamlit_app_tfidf.py      # Streamlit UI using TF-IDF
├── requirements.txt            # Python dependencies
├── Dockerfile                  # Container startup configuration
├── _data/                      # Knowledge-base text files
│   ├── company_hr_policy.txt
│   ├── engineering_standards.txt
│   ├── onboarding_guide.txt
│   ├── product_knowledge_base.txt
│   └── security_policy.txt
└── README.md
```

## How it works

```text
User question
     │
     ▼
Load and chunk .txt documents
     │
     ├── ChromaDB: create semantic embeddings
     └── TF-IDF: build a keyword-based document-term matrix
     │
     ▼
Retrieve the three most relevant chunks
     │
     ▼
Add the chunks and question to an LLM prompt
     │
     ▼
Groq generates an answer grounded in the retrieved context
     │
     ▼
Return the answer and source filenames
```

For a normal question, the application:

1. Reads `.txt` files from `_data/`.
2. Splits each document into paragraphs.
3. Skips short fragments and section divider lines.
4. Retrieves the top three relevant chunks.
5. Sends those chunks as context to the language model.
6. Requests a concise answer and returns the source documents.

The prompt instructs the model to answer only from the supplied context.

## Tools and technologies used

| Tool or technology | Purpose in Cognify AI |
|---|---|
| Python 3.11 | Main implementation language |
| Streamlit | Browser chat interface, chat history, and source/chunk display |
| FastAPI | REST backend and automatic API documentation |
| Pydantic | Validation of `/chat` request and response JSON |
| Uvicorn | ASGI server used to run the FastAPI application |
| Groq API | Hosted model inference for fast answer generation |
| OpenAI Python SDK | OpenAI-compatible client used to call the Groq chat-completions endpoint |
| ChromaDB | In-memory semantic vector store and embedding search |
| scikit-learn | TF-IDF vectorization and cosine-similarity retrieval |
| NumPy | Ranking and selecting the highest-scoring TF-IDF chunks |
| python-dotenv | Loading the local `groq_api_key` from `.env` |
| Docker | Packaging and running the application consistently |
| Git and GitHub | Source control and deployment repository |
| VS Code | Development, debugging, and project management |

The Streamlit and API applications use two different model configurations depending on the entry point:

- `streamlit_app.py` and `main.py` use `llama-3.3-70b-versatile` or `openai/gpt-oss-120b` in the Groq chat-completions API.
- `streamlit_app_tfidf.py` uses `openai/gpt-oss-120b`.
- All generation calls use a `temperature` of `0.2` to keep responses factual and consistent.

The `.env` file is used only for local development. On deployment platforms, `groq_api_key` is configured as a secret environment variable.

## RAG functioning

RAG combines information retrieval with text generation. The full workflow used in this project is:

### Retrieval

1. Text files are read from `_data/`.
2. Every file is split by blank-line paragraph boundaries.
3. Short fragments and section-divider lines are filtered out.
4. The remaining text and source filenames become document chunks.
5. A ChromaDB collection or TF-IDF matrix is created from those chunks.
6. The user's question is transformed using the same retrieval method.
7. The three chunks with the highest relevance are selected.

### Augmentation

The selected chunk text is combined into a context block. The question and context are included in the chat-completion prompt. A system message specifies that the model must use only the context and should decline if the information is not available.

### Generation

Groq receives the augmented prompt and generates the final answer. The answer is then paired with the source filenames and displayed in Streamlit or returned as JSON by FastAPI.

```text
Document source
    -> Paragraph chunking
    -> Vector or TF-IDF index
    -> User question
    -> Top-three relevant chunks
    -> Prompt with grounded context
    -> Groq language model
    -> Answer + source documents
```

## Project implementation

Cognify AI was implemented as a practical RAG prototype rather than a direct chatbot that relies only on a language model's built-in knowledge.

### 1. Prepared the knowledge base

The project uses plain-text company documents stored in `_data/`. The files represent several categories of information:

- Human resources policies
- Engineering conventions
- Onboarding instructions
- Product descriptions
- Security requirements

Plain text was chosen so the knowledge source remains easy to edit, inspect, version-control, and add to during development.

### 2. Added document chunking

Each text file is divided using blank-line paragraph boundaries. This keeps related sentences together while creating retrieval units small enough to fit into an LLM context window.

Before indexing, the implementation:

- Removes leading and trailing whitespace.
- Skips paragraph fragments shorter than 50 characters.
- Skips section-divider lines beginning with `====`.
- Records the source filename alongside each chunk.

This chunking approach is intentionally simple and predictable. For larger or less structured documents, sentence-windowing, fixed-size overlapping chunks, or heading-aware chunking could be added later.

### 3. Built two retrieval implementations

The project includes semantic and lightweight retrieval implementations so it can be compared in different environments.

#### ChromaDB semantic retrieval

[`streamlit_app.py`](streamlit_app.py) uses an in-memory ChromaDB collection. ChromaDB creates vector embeddings for document chunks and compares them with an embedding of the user's question.

This approach is useful because it can retrieve text with similar meanings even when the question does not use the exact document wording.

#### TF-IDF retrieval

[`streamlit_app_tfidf.py`](streamlit_app_tfidf.py) converts documents and questions into TF-IDF vectors. It uses unigrams and bigrams, English stop-word removal, cosine similarity, and the three highest-ranked chunks.

TF-IDF was added as a deployment-friendly alternative. It does not download an embedding model and consumes substantially less memory.

### 4. Grounded the answer generation

The retrieved chunks are combined into a context block and sent to Groq through an OpenAI-compatible client. The system prompt instructs the model to:

- Answer only from the supplied context.
- Avoid unsupported claims.
- Say that it does not have enough information when the context is insufficient.
- Keep the response concise and direct.

A low temperature is used for more consistent and factual output.

### 5. Added source visibility

Answers are returned with the source filenames used during retrieval. The Streamlit interface also stores retrieved chunk text and exposes it in a collapsible section.

This makes the prototype more transparent: users can verify whether an answer was supported by the retrieved document content rather than trusting the generated response alone.

### 6. Built both UI and API experiences

The Streamlit applications provide an interactive chat experience:

- Conversation messages are stored in `st.session_state`.
- Streamlit reruns the script after interactions.
- Cached resources prevent the document index from being rebuilt for every chat message.
- Users can inspect source documents and retrieved chunks.

The FastAPI backend in [`main.py`](main.py) provides a reusable JSON interface with Pydantic request and response validation. It exposes:

- `/` for a basic health response.
- `/chat` for question answering.
- `/docs` for interactive Swagger documentation.
- `/redoc` for ReDoc documentation.

Each API chat request is assigned a short request ID to correlate application logs.

### 7. Containerized the application

The Dockerfile uses Python 3.11 and installs dependencies before copying the application. It runs the TF-IDF Streamlit app on port `10000` by default to reduce memory use on constrained hosting plans. For local semantic search, run `streamlit_app.py` directly.

## Design decisions

| Decision | Reason |
|---|---|
| Plain-text documents | Easy to read, edit, and version-control |
| Paragraph chunking | Simple and suitable for structured company documents |
| Top-three retrieval | Limits context size while usually providing enough supporting text |
| Groq-hosted models | OpenAI-compatible API with fast chat-completion inference |
| Low temperature | Reduces randomness and makes answers more consistent |
| ChromaDB alternative | Demonstrates semantic vector retrieval |
| TF-IDF alternative | Demonstrates a lightweight retrieval option for constrained hosts |
| Source and chunk display | Improves answer traceability and debugging |
| FastAPI and Streamlit | Separates a reusable API from an interactive demonstration UI |

## Prerequisites

- Python 3.11 or later
- A Groq API key
- Docker, if running in a container

Create a Groq API key from <https://console.groq.com/>.

## Installation

Clone the repository and enter the project directory:

```bash
git clone <YOUR_REPOSITORY_URL>
cd cognify_ai
```

### Create a virtual environment

**Windows PowerShell**

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
```

**macOS/Linux**

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### Install dependencies

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### Configure the API key

Create a `.env` file in the project root:

```dotenv
groq_api_key=gsk_your_groq_api_key
```

Do not commit `.env` or paste API keys into source code or screenshots.

For hosted environments, set `groq_api_key` as an environment variable instead of creating a `.env` file.

## Run the Streamlit application

### ChromaDB/semantic version

```bash
streamlit run streamlit_app.py
```

Open <http://localhost:8501>.

This version uses semantic embeddings and is recommended for local demos when sufficient memory is available.

### TF-IDF lightweight version

```bash
streamlit run streamlit_app_tfidf.py
```

Open <http://localhost:8501>.

This version uses TF-IDF and cosine similarity. It has a smaller memory footprint and no embedding-model download, making it suitable for constrained hosting environments.

## Run the FastAPI backend

Start the API from the project root:

```bash
uvicorn main:app --reload --port 8000
```

Interactive API documentation is available at:

- Swagger UI: <http://localhost:8000/docs>
- ReDoc: <http://localhost:8000/redoc>

### Health check

```bash
curl http://localhost:8000/
```

### Ask a question

**Windows PowerShell**

```powershell
$body = @{
    question = "What is the work-from-home policy?"
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "http://localhost:8000/chat" -ContentType "application/json" -Body $body
```

**curl**

```bash
curl -X POST "http://localhost:8000/chat" \
  -H "Content-Type: application/json" \
  -d '{"question":"What is the work-from-home policy?"}'
```

Example response:

```json
{
  "answer": "Employees may work remotely according to the policy described in the company documents.",
  "sources": [
    "company_hr_policy.txt"
  ],
  "request_id": "a46a0fb7"
}
```

## Add or update knowledge

1. Add or edit `.txt` files inside `_data/`.
2. Restart the application so the documents are indexed again.
3. Ask a question that uses terminology from the updated document.
4. Expand **View retrieved document chunks** to verify retrieval quality.

The indexing code skips paragraphs shorter than 50 characters and lines beginning with `====`. If a document uses different formatting, adjust the chunking implementation in the selected entry point:

- [`streamlit_app.py`](streamlit_app.py)
- [`streamlit_app_tfidf.py`](streamlit_app_tfidf.py)
- [`main.py`](main.py)

## Run with Docker

Build the image:

```bash
docker build -t cognify-ai .
```

Run the container:

```bash
docker run --rm -p 10000:10000 \
  -e groq_api_key="gsk_your_groq_api_key" \
  cognify-ai
```

Open <http://localhost:10000>.

The Dockerfile starts `streamlit_app_tfidf.py` by default to avoid loading ChromaDB's embedding model in memory. To use semantic retrieval in a machine with more available memory, change its final `CMD` to run `streamlit_app.py`.

## Deploy to a platform

The application can be deployed as a Docker web service. In the hosting platform:

1. Connect the Git repository.
2. Choose Docker as the build/runtime type.
3. Set the exposed/internal port to `10000`.
4. Add `groq_api_key` to the secret or environment-variable settings.
5. Deploy the service.
6. Verify the health endpoint or open the public URL.

Because free hosting tiers may have limited memory, the Dockerfile uses the TF-IDF entry point by default.

## Retrieval options

| Option | Implementation | Best use |
|---|---|---|
| ChromaDB | Semantic embedding search | Local demos and general text |
| TF-IDF | Keyword and n-gram cosine similarity | Constrained hosting and structured documents |

TF-IDF is faster and more memory-efficient, but it generally handles synonyms less well than semantic embeddings.

## Troubleshooting

| Problem | Possible fix |
|---|---|
| `groq_api_key` is missing | Create `.env` with `groq_api_key=...`, or set the environment variable on the host |
| `_data/ folder not found` | Run commands from the project root and ensure `_data/` is present |
| Streamlit is blank or fails to start | Activate the virtual environment and run `python -m pip install -r requirements.txt` |
| ChromaDB uses too much memory | Use `streamlit_app_tfidf.py` or change the Docker `CMD` to that file |
| Answers appear unrelated | Try wording closer to the knowledge-base documents and inspect retrieved chunks |
| FastAPI cannot run | Install the dependencies and start with `uvicorn main:app --reload --port 8000` |

## Security

- Never commit `.env`, API keys, or credentials.
- Use hosted-environment secret management in production.
- The provided knowledge base is a local example and should not contain confidential or regulated data unless access controls and policies are in place.
- Validate and moderate any questions or answers before exposing the service to an untrusted audience.

## Technology

### Core stack

- **Language:** Python 3.11
- **AI technique:** Retrieval-Augmented Generation
- **LLM provider:** Groq
- **LLM API format:** OpenAI-compatible chat completions
- **Semantic retrieval:** ChromaDB
- **Lightweight retrieval:** scikit-learn TF-IDF
- **Vector similarity:** Cosine similarity
- **Frontend:** Streamlit
- **Backend:** FastAPI and Uvicorn
- **Configuration:** python-dotenv and environment variables
- **Containerization:** Docker
- **Development:** VS Code, Python virtual environments, and Git

### RAG components

- **Knowledge ingestion:** `_data/*.txt` files
- **Chunking:** Blank-line paragraph splitting
- **Chunk filtering:** Minimum 50-character length
- **Retrieval count:** Top three chunks
- **Answer generation:** Groq chat completions
- **Generation temperature:** `0.2`
- **Traceability:** Source filenames and retrieved chunk display
