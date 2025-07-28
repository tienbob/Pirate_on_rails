import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["popup", "open", "close", "form", "input", "messages"];

  connect() {
    // Subscribe to Action Cable for live updates (always active)
    if (!this.cableSubscribed) {
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
              const contentMatch = aiText.match(/content="([\s\S]*?)"/);
              if (contentMatch) {
                aiText = contentMatch[1].replace(/\\n/g, "\n");
              }
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
    this.formTarget.addEventListener("submit", async (e) => {
      e.preventDefault();
      const msg = this.inputTarget.value.trim();
      if (msg) {
        // Show user message immediately
        this.appendMessage({ user_message: msg });
        this.inputTarget.value = "";
        this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;

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

  appendMessage(msg) {
    // User message
    if (msg.user_message) {
      const userDiv = document.createElement("div");
      userDiv.textContent = msg.user_message;
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
    // AI message (support agent_message, message, and content keys, prefer agent_message > content > message)
    let aiText = null;
    if (msg.agent_message) {
      aiText = msg.agent_message;
    } else if (msg.content && !msg.user_message) {
      aiText = msg.content;
    } else if (msg.message && !msg.user_message) {
      aiText = msg.message;
    }
    if (aiText) {
      const aiDiv = document.createElement("div");
      aiDiv.textContent = aiText;
      aiDiv.style.margin = "8px 0";
      aiDiv.style.textAlign = "left";
      aiDiv.style.background = "#e3f2fd";
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
    }
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }

  subscribeToChatChannel() {
    if (window.App && window.App.cable) {
      this.subscription = window.App.cable.subscriptions.create({ channel: "ChatChannel" }, {
        received: (data) => {
          this.appendMessage(data);
        }
      });
    } else if (window.cable) {
      // For Rails 7 importmap default
      import("@rails/actioncable").then(ActionCable => {
        this.subscription = ActionCable.createConsumer().subscriptions.create({ channel: "ChatChannel" }, {
          received: (data) => {
            this.appendMessage(data);
          }
        });
      });
    }
  }
}
