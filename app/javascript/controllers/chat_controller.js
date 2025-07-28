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
            this.appendMessage(msg);
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

    // Helper to append messages
    this.appendMessage = (msg) => {
      if (msg.user_message) {
        const userDiv = document.createElement("div");
        userDiv.textContent = msg.user_message;
        userDiv.style.margin = "8px 0";
        userDiv.style.textAlign = "right";
        userDiv.style.color = "#222";
        this.messagesTarget.appendChild(userDiv);
      }
      if (msg.ai_response) {
        const aiDiv = document.createElement("div");
        aiDiv.textContent = msg.ai_response;
        aiDiv.style.margin = "8px 0";
        aiDiv.style.textAlign = "left";
        aiDiv.style.color = "#007bff";
        this.messagesTarget.appendChild(aiDiv);
      }
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
    };

    // Action Cable subscription
    this.subscribeToChatChannel = () => {
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
    };
  }
}
