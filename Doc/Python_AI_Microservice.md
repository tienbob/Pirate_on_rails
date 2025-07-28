# Python AI Microservice Documentation

## Overview
This microservice acts as the AI agent for the Pirate On Rails platform. It receives user chat messages from Rails, analyzes them using NLP and RAG (Retrieval-Augmented Generation), and interacts with Rails to fetch movie and tag data for semantic search and response generation.

---

## API Endpoints

### `/chat` (POST)
- Receives user chat messages from Rails.
- Returns AI-generated responses.

### `/health` (GET)
- Health check endpoint.

### `/chats/movies_data` (GET)
- Returns all movie data (title, description, tags, is_pro) for semantic search and embedding.

### `/chats/history` (GET)
- Returns chat history for the current user (user messages and AI responses, ordered by time).

---

## Data Sync & Indexing
- On startup or schedule, fetch all movies from Rails (`/chats/movies_data`).
- Build and maintain a FAISS index with embeddings for semantic search.
- Re-sync and rebuild index when data changes in Rails.

---

## Semantic Search with FAISS
- Use SentenceTransformers or similar to embed movie docs.
- Store embeddings in FAISS for fast similarity search.
- For each user query, embed the query and use FAISS to retrieve relevant movies.
- Optionally, apply metadata filters (year, tags) to FAISS results.

---

---

## Security & Maintenance
- Validate all requests.
- Use authentication if exposing endpoints publicly.
- Monitor health and logs.
- Keep dependencies up to date.
- Rebuild FAISS index when data changes.

---

## Real-Time Chat Integration
- Rails now uses Action Cable to broadcast new chat messages and AI responses to users in real time.
- The frontend subscribes to `ChatChannel` for instant updates.
- No polling required; AI responses are delivered via WebSocket.

---

## Contact
For integration issues or feature requests, contact the Rails backend team or the AI microservice maintainer.
