import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["popup", "open", "close", "form", "input", "messages"];

  connect() {
    // Subscribe to Action Cable for live updates (always active)
    if (!this.cableSubscribed) {
      // Get current user id from meta tag
      const meta = document.querySelector('meta[name="current-user-id"]');
      this.currentUserId = meta ? meta.getAttribute('content') : null;
      console.log("Subscribing to ChatChannel...", this.currentUserId);
      this.subscribeToChatChannel();
      this.cableSubscribed = true;
    }
    this.openTarget.addEventListener("click", async () => {
      this.popupTarget.style.display = "flex";
      this.openTarget.style.display = "none";
      // Fetch and display chat history
      try {
        const response = await fetch("/chats/history");
        if (response.ok) {
          const data = await response.json();
          this.messagesTarget.innerHTML = "";
          data.history.forEach(msg => {
            // Render user message
            if (msg.user_message) {
              this.appendMessage({ user_message: msg.user_message });
            }
            // Render AI message
            if (msg.ai_response) {
              // Try to extract content from ai_response if present
              let aiText = msg.ai_response;
              this.appendMessage({ agent_message: aiText });
            }
          });
          this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
        }
      } catch (err) {
        // Optionally show error
      }
    });
    this.closeTarget.addEventListener("click", () => {
      this.popupTarget.style.display = "none";
      this.openTarget.style.display = "flex";
    });
    // Auto-expand textarea as user types
    this.inputTarget.addEventListener("input", function() {
      this.style.height = 'auto';
      this.style.height = (this.scrollHeight) + 'px';
    });
    this.formTarget.addEventListener("submit", async (e) => {
      e.preventDefault();
      const msg = this.inputTarget.value.trim();
      if (msg) {
        // Show user message immediately
        this.appendMessage({ user_message: msg });
        this.inputTarget.value = "";
        this.inputTarget.style.height = 'auto';
        this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;

        // Show animated AI loading indicator
        this.showAILoading();

        // Send to backend via AJAX
        const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
        try {
          await fetch("/chats", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": csrfToken
            },
            body: JSON.stringify({ message: msg })
          });
          // AI response will arrive via Action Cable
        } catch (err) {
          this.removeAILoading();
          const errDiv = document.createElement("div");
          errDiv.textContent = "Network error.";
          errDiv.style.margin = "8px 0";
          errDiv.style.textAlign = "left";
          errDiv.style.color = "#dc3545";
          this.messagesTarget.appendChild(errDiv);
          this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
        }
      }
    });
  }
  showAILoading() {
    this.removeAILoading();
    const loadingDiv = document.createElement("div");
    loadingDiv.className = "ai-loading-indicator";
    loadingDiv.innerHTML = `
      <span class="ai-dots">
        <span class="dot">.</span><span class="dot">.</span><span class="dot">.</span>
      </span>
      <span style="margin-left:8px; color:#888; font-style:italic;">AI is thinking</span>
      <style>
        .ai-dots .dot {
          animation: ai-blink 1.4s infinite both;
          font-size: 1.5em;
          color: #888;
        }
        .ai-dots .dot:nth-child(2) { animation-delay: 0.2s; }
        .ai-dots .dot:nth-child(3) { animation-delay: 0.4s; }
        @keyframes ai-blink {
          0%, 80%, 100% { opacity: 0; }
          40% { opacity: 1; }
        }
      </style>
    `;
    loadingDiv.style.margin = "8px 0";
    loadingDiv.style.textAlign = "left";
    loadingDiv.style.background = "#f3f3f3";
    loadingDiv.style.color = "#888";
    loadingDiv.style.borderRadius = "8px";
    loadingDiv.style.padding = "10px 14px";
    loadingDiv.style.display = "inline-block";
    loadingDiv.style.maxWidth = "85%";
    loadingDiv.style.fontSize = "1em";
    loadingDiv.style.whiteSpace = "pre-line";
    loadingDiv.style.float = "left";
    this.messagesTarget.appendChild(loadingDiv);
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  };

  // Remove the loading indicator
  removeAILoading() {
    const loadingDiv = this.messagesTarget.querySelector('.ai-loading-indicator');
    if (loadingDiv) {
      loadingDiv.remove();
    }
  }
  // If skipUser is true, do not render user_message (for Action Cable events)
  appendMessage(msg, skipUser = false) {
    // Debug: log all incoming messages
    console.log("[Chat] appendMessage received:", msg);

    // Support nested message object (from Action Cable broadcast)
    let payload = msg;
    if (msg.message && typeof msg.message === 'object') {
      payload = { ...msg, ...msg.message };
    }

    // Only show user message if not skipping (skipUser is false)
    if (!skipUser && payload.user_message) {
      const userDiv = document.createElement("div");
      userDiv.textContent = payload.user_message;
      userDiv.style.margin = "8px 0";
      userDiv.style.textAlign = "right";
      userDiv.style.background = "#e3f2fd";
      userDiv.style.color = "#222";
      userDiv.style.borderRadius = "8px";
      userDiv.style.padding = "10px 14px";
      userDiv.style.display = "inline-block";
      userDiv.style.maxWidth = "85%";
      userDiv.style.boxShadow = "0 1px 6px rgba(0,0,0,0.09)";
      userDiv.style.fontSize = "1em";
      userDiv.style.whiteSpace = "pre-line";
      userDiv.style.float = "right";
      this.messagesTarget.appendChild(userDiv);
    }

    // Robustly extract AI message from both top-level and nested message
    let aiText = null;
    // Check top-level fields
    if (payload.agent_message) {
      aiText = payload.agent_message;
    } else if (payload.ai_response) {
      aiText = payload.ai_response;
    } else if (payload.content) {
      aiText = payload.content;
    }
    // If not found, check nested message object
    if (!aiText && payload.message && typeof payload.message === 'object') {
      if (payload.message.agent_message) {
        aiText = payload.message.agent_message;
      } else if (payload.message.ai_response) {
        aiText = payload.message.ai_response;
      } else if (payload.message.content) {
        aiText = payload.message.content;
      }
    }
    console.log("[Chat] appendMessage extracted aiText:", aiText);
    if (aiText) {
      this.removeAILoading();
      let filtered = this.filterAIResponse(aiText);
      const aiDiv = document.createElement("div");
      aiDiv.textContent = filtered.trim();
      aiDiv.style.margin = "8px 0";
      aiDiv.style.textAlign = "left";
      aiDiv.style.background = "#d4f8e8";
      aiDiv.style.color = "#222";
      aiDiv.style.borderRadius = "8px";
      aiDiv.style.padding = "10px 14px";
      aiDiv.style.display = "inline-block";
      aiDiv.style.maxWidth = "85%";
      aiDiv.style.boxShadow = "0 1px 6px rgba(0,0,0,0.09)";
      aiDiv.style.fontSize = "1em";
      aiDiv.style.whiteSpace = "pre-line";
      aiDiv.style.float = "left";
      this.messagesTarget.appendChild(aiDiv);
    } else if (skipUser) {
      // If skipUser is true and no AI message found, log a warning
      this.removeAILoading();
      console.warn("[Chat] No AI message found in Action Cable payload:", msg);
    }
  }

  // General filter for AI responses: removes duplicate lines, collapses repeated blocks, trims whitespace
  filterAIResponse(text) {
    // Remove exact duplicate lines (keep first occurrence)
    let lines = text.split('\n');
    let seen = new Set();
    let deduped = lines.filter(line => {
      let trimmed = line.trim();
      if (trimmed === '' || seen.has(trimmed)) return false;
      seen.add(trimmed);
      return true;
    });
    let filtered = deduped.join('\n');
    // Collapse repeated blocks of 3+ identical lines
    filtered = filtered.replace(/(.*(?:\n|$)){3,}/g, (block) => {
      let blockLines = block.trim().split('\n');
      if (blockLines.length > 2 && new Set(blockLines).size === 1) {
        return blockLines[0] + '\n';
      }
      return block;
    });
    // Remove excessive whitespace
    filtered = filtered.replace(/\n{3,}/g, '\n\n');
    return filtered;
  }

  // Ensure scroll after message append
  scrollMessagesToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }

  subscribeToChatChannel() {
    const identifier = { channel: "ChatChannel", id: this.currentUserId };
    console.log("[Chat] subscribeToChatChannel called. window.App:", window.App);
    const handleAIResponse = (data) => {
      // Pass the original data object, let appendMessage extract the AI field
      this.appendMessage(data, true);
    };
    if (window.App && window.App.cable) {
      console.log("[Chat] window.App.cable is present. Subscribing to ChatChannel with identifier:", identifier);
      this.subscription = window.App.cable.subscriptions.create(identifier, {
        received: (data) => {
          console.log("[Chat] Received data from Action Cable:", data);
          handleAIResponse(data);
        }
      });
    } else if (window.cable) {
      console.log("[Chat] window.cable is present. Using fallback import for ActionCable.");
      import("@rails/actioncable").then(ActionCable => {
        this.subscription = ActionCable.createConsumer().subscriptions.create(identifier, {
          received: (data) => {
            console.log("[Chat] Received data from fallback Action Cable:", data);
            handleAIResponse(data);
          }
        });
      });
    } else {
      console.error("[Chat] No Action Cable client found! window.App:", window.App, "window.cable:", window.cable);
    }
  }
}
