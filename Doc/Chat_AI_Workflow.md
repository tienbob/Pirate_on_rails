# Chat-AI-Rails Workflow Documentation

## Overview
This document describes the end-to-end workflow for integrating a chat popup in a Ruby on Rails application with a Python-based AI RAG (Retrieval-Augmented Generation) agent, including how user messages are processed, how movie data is retrieved, and how responses are delivered.

---

## Workflow Steps

### 1. User Interaction (Frontend)
- The user enters a message in the chat popup on any page.
- The message is sent via AJAX (using Stimulus controller and fetch) to the Rails backend (`POST /chats`).

### 2. Rails Receives Message
- `ChatsController#create` receives the user message.
- Rails immediately forwards the message to the Python AI agent via HTTP (`POST http://localhost:5000/chat`).
- The message is stored in the `Chat` model for history/audit.

### 3. Python AI Agent (RAG)
- The Python agent receives the message.
- It analyzes the message using NLP to determine intent (e.g., search, recommendation, general question).
- If the message requires movie data (e.g., search, recommendation):
    - The Python agent sends a search request to Rails (`GET /chats/search`) with extracted parameters (query, year, tags, etc.).
    - Rails performs the search using its Elasticsearch logic and returns relevant movie documents as JSON.
- The Python agent uses the movie data (and/or other context) to generate a response using its RAG pipeline.
- If no search is needed, the agent generates a response directly.

### 4. Rails Search Endpoint
- The `/chats/search` endpoint uses the shared `Searchable` concern to perform movie searches.
- It applies business logic, permissions, and Elasticsearch queries to return only allowed/visible movies.

### 5. Python AI Agent Responds
- The Python agent sends the final response (chat message) back to Rails (`POST /chats` response).

### 6. Rails Delivers Response
- Rails receives the AI response and stores it in the `Chat` model.
- Rails sends the response back to the frontend as JSON.
- The chat popup displays the AI response to the user.

---

## Key Architectural Points
- **Rails controls business logic, permissions, and data access.**
- **Python agent handles AI/NLP, orchestration, and RAG.**
- **Communication is via HTTP API endpoints.**
- **Movie search logic is shared via a Rails concern (`Searchable`).**
- **All chat history is stored in the Rails database.**

---

## Example Sequence
1. User: "Show me movies from 2010 with action tags."
2. Rails: Forwards message to Python agent.
3. Python agent: Extracts year and tags, calls `/chats/search?q=&year_from=2010&year_to=2010&tags[]=action`.
4. Rails: Returns matching movies.
5. Python agent: Generates response using RAG and movie docs.
6. Rails: Delivers response to user and stores chat.

---

## Extensibility
- You can add more endpoints (e.g., for recommendations, user context).
- You can expand the Python agent to handle more complex workflows.
- You can display chat history or analytics in Rails views.

---

## Security & Permissions
- All data access and filtering is handled by Rails, ensuring security and compliance.
- Python agent does not access the database directly; it uses Rails APIs.

---

## Maintenance
- Search logic changes only need to be updated in the Rails concern.
- Python agent can be updated independently for AI improvements.

---

## Summary
This workflow ensures a secure, maintainable, and flexible integration between Rails and a Python AI agent, supporting advanced chat and search features for your movie app.
