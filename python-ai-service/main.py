from fastapi import FastAPI
from contextlib import asynccontextmanager
import uvicorn
import requests
import os
import logging
import threading
import time
from typing import List, Dict
from pydantic import BaseModel
import faiss
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.messages import HumanMessage, AIMessage
from langchain.agents import create_tool_calling_agent, AgentExecutor, Tool
import wikipedia
from dotenv import load_dotenv
load_dotenv()

# --- Models ---
from typing import Optional

class ChatRequest(BaseModel):
    message: str
    user_id: Optional[str] = None

# --- Startup/Shutdown Logic ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global FAISS_INDEX, DOCS, EMBEDDINGS
    series = fetch_series_data()
    if series:
        FAISS_INDEX, DOCS, EMBEDDINGS = build_faiss_index(series)
        logging.info(f"FAISS index built with {len(DOCS)} series and movies.")
    # Start periodic refresh every 8 hours
    refresh_faiss_index_periodically(28800)
    yield
    # Shutdown (if needed)

# --- App Setup ---
app = FastAPI(lifespan=lifespan)
logging.basicConfig(level=logging.INFO)

# --- Globals ---
SERIES_DATA_URL = os.getenv("SERIES_DATA_URL")
FAISS_INDEX = None
DOCS = []
EMBEDDINGS = None
CHAT_HISTORY = {}  # user_id -> list of (user, ai) (legacy, not used for fetching)

# --- Helper Functions ---
def fetch_series_data():
    try:
        resp = requests.get(SERIES_DATA_URL)
        resp.raise_for_status()
        data = resp.json()
        # If the API returns {"series": [...]}, extract the list
        if isinstance(data, dict) and "series" in data:
            series = data["series"]
        else:
            series = data
        logging.info(f"Fetched series data: {type(series)} | First item: {series[0] if series else 'None'}")
        return series
    except Exception as e:
        logging.error(f"Failed to fetch series data: {e}")
        return []

def build_faiss_index(series: List[Dict]):
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('all-MiniLM-L6-v2')
    docs = []
    for s in series:
        if isinstance(s, dict):
            title = s.get('title', '')
            desc = s.get('description', '')
            tags = ' '.join(s.get('tags', [])) if isinstance(s.get('tags', []), list) else str(s.get('tags', ''))
            # Add main series info
            docs.append(f"Series: {title}\nDescription: {desc}\nTags: {tags}")
            # Add each episode as a separate doc
            episodes = s.get('episodes', [])
            for ep in episodes:
                if isinstance(ep, dict):
                    ep_title = ep.get('title', '')
                    ep_desc = ep.get('description', '')
                    ep_tags = ' '.join(ep.get('tags', [])) if isinstance(ep.get('tags', []), list) else str(ep.get('tags', ''))
                    docs.append(f"Episode: {ep_title}\nSeries: {title}\nDescription: {ep_desc}\nTags: {ep_tags if ep_tags else tags}")
        else:
            docs.append(str(s))
    if not docs:
        logging.error("No valid series docs to index.")
        return None, [], None
    embeddings = model.encode(docs)
    index = faiss.IndexFlatL2(embeddings.shape[1])
    index.add(embeddings)
    return index, docs, model


# --- LangChain Tool for Semantic Search ---
def semantic_search_tool(query: str, k: int = 5) -> str:
    """Searches for relevant series and episodes based on the user's query."""
    if FAISS_INDEX is None or EMBEDDINGS is None:
        return "No data available."
    q_emb = EMBEDDINGS.encode([query])
    D, I = FAISS_INDEX.search(q_emb, k)
    results = [DOCS[i] for i in I[0]]
    return "\n".join(results)


semantic_search_langchain_tool = Tool(
    name="semantic_search",
    func=semantic_search_tool,
    description="Search for relevant series and episodes based on a user's query. Use this tool to find information about movies, series, or episodes."
)

# --- LangChain Tool for Wikipedia Search ---
def wikipedia_search_tool(query: str) -> str:
    """Searches Wikipedia for movie/series details not covered in the local docs."""
    try:
        results = wikipedia.search(query, results=1)
        if not results:
            return "No Wikipedia results found."
        page = wikipedia.page(results[0])
        summary = wikipedia.summary(results[0], sentences=3)
        return f"Wikipedia: {page.title}\n{summary}"
    except Exception as e:
        return f"Wikipedia search error: {e}"

wikipedia_langchain_tool = Tool(
    name="wikipedia_search",
    func=wikipedia_search_tool,
    description="Search Wikipedia for movie or series details not found in the local database. Use this tool if the user's question cannot be answered from the provided docs."
)

def add_chat_history(user_id: str, user_msg: str, ai_msg: str):
    if user_id not in CHAT_HISTORY:
        CHAT_HISTORY[user_id] = []
    CHAT_HISTORY[user_id].append({"user": user_msg, "ai": ai_msg})


# Fetch chat history from Rails backend (10 newest)
def get_chat_history(user_id: str):
    try:
        rails_url = os.getenv("RAILS_HISTORY_URL", "http://localhost:3000/chats/history")
        resp = requests.get(rails_url, params={"user_id": user_id}, timeout=5)
        resp.raise_for_status()
        data = resp.json()
        # Expecting {"history": [{"user": ..., "ai": ..., "created_at": ...}, ...]}
        history = data.get("history", [])
        # Sort by created_at descending if present, else as is
        if history and "created_at" in history[0]:
            history = sorted(history, key=lambda x: x["created_at"], reverse=True)
        # Take 10 newest, reverse to chronological order
        history = list(reversed(history[:10]))
        return history
    except Exception as e:
        logging.error(f"Failed to fetch chat history from Rails: {e}")
        return []

def refresh_faiss_index_periodically(interval_sec=28800):
    # refresh the FAISS index periodically 8h each
    def refresh():
        global FAISS_INDEX, DOCS, EMBEDDINGS
        while True:
            series = fetch_series_data()
            if series:
                FAISS_INDEX, DOCS, EMBEDDINGS = build_faiss_index(series)
                logging.info(f"[Periodic] FAISS index rebuilt with {len(DOCS)} series and movies.")
            time.sleep(interval_sec)
    t = threading.Thread(target=refresh, daemon=True)
    t.start()

# --- Endpoints ---
@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/chats/series_data")
def series_data():
    series = fetch_series_data()
    return {"series": series}

@app.get("/chats/history")
def chats_history(user_id: str):
    return {"history": get_chat_history(user_id)}

@app.post("/chat")
async def chat_endpoint(req: ChatRequest):
    # Per-user history support
    user_id = req.user_id if req.user_id else "anonymous"
    # Get chat history for user and convert to LangChain message objects
    history = get_chat_history(user_id)
    chat_history_msgs = []
    if history:
        for entry in history:
            chat_history_msgs.append(HumanMessage(content=entry['user']))
            chat_history_msgs.append(AIMessage(content=entry['ai']))

    llm = ChatGoogleGenerativeAI(model="gemini-2.0-flash", temperature=1, api_key=os.getenv("GEMINI_API_KEY"))
    tools = [semantic_search_langchain_tool, wikipedia_langchain_tool]
    prompt = ChatPromptTemplate.from_messages([
        ('system', '''You are an intelligent assistant. 
         Use the semantic_search tool to find relevant movie, series, and episode information 
         (including series tags as movie tags) to answer user questions about movies, series, episodes, or general entertainment topics.
         If the user asks for more details about a movie or series that is not in the local database, or if your answer is
         incomplete, short, or vague, always use the wikipedia_search tool to look up and provide additional information. 
         Your responses should be concise, relevant, and informative, and combine both sources if needed.
         '''),
        ("placeholder", "{chat_history}"),
        ("human", "{input}"),
        ("placeholder", "{agent_scratchpad}"),
    ])
    agent = create_tool_calling_agent(
        tools=tools,
        llm=llm,
        prompt=prompt
    )
    executor = AgentExecutor(agent=agent, tools=tools, verbose=True, handle_parsing_errors=True)
    try:
        result = executor.invoke({"input": req.message, "chat_history": chat_history_msgs})
        if isinstance(result, dict):
            ai_msg = result.get('output', '') or result.get('content', '')
        else:
            ai_msg = str(result)
    except Exception as e:
        logging.error(e)
        ai_msg = "Sorry, AI service unavailable."
    add_chat_history(user_id, req.message, ai_msg)
    return {"response": ai_msg}

# --- Main ---
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
