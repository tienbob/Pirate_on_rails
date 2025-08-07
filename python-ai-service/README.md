# Pirate_on_rails AI Agent Microservice

This project is an AI-powered microservice for the Pirate_on_rails platform. It provides intelligent, context-aware responses to user queries about movies, series, and general entertainment topics, leveraging Retrieval-Augmented Generation (RAG) and semantic search.

## Features
- FastAPI-based REST API
- Semantic search using FAISS and SentenceTransformers
- Integrates with Google Gemini (via LangChain)
- Periodically syncs and indexes movie/series/episode data from the Rails backend
- Supports chat history per user
- Designed for real-time chat integration with Rails (Action Cable)

## Endpoints
- `POST /chat` — Receives a user message and returns an AI-generated response
- `GET /health` — Health check endpoint
- `GET /chats/series_data` — Returns all series data for semantic search and embedding
- `GET /chats/history?user_id=...` — Returns chat history for a user

## Data Sync & Indexing
- Fetches all series (and episodes) from the Rails backend
- Builds and maintains a FAISS index for fast semantic search
- Rebuilds the index every 8 hours automatically

## Semantic Search
- Uses SentenceTransformers to embed series and episode docs
- Stores embeddings in FAISS for fast similarity search
- For each user query, retrieves relevant series/episodes for the LLM context

## Setup
1. Clone this repo
2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```
3. Set up your `.env` file with required environment variables (e.g., `GEMINI_API_KEY`, `SERIES_DATA_URL`)
4. Run the service:
   ```
   uvicorn app:app --reload --port 5000
   ```

## Security & Maintenance
- Validate all requests
- Use authentication if exposing endpoints publicly
- Monitor health and logs
- Keep dependencies up to date

## License
MIT
