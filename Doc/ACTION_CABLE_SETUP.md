# Action Cable Setup and Usage Guide (Rails 8, Importmap, Stimulus)

This guide summarizes the steps and troubleshooting tips for setting up Action Cable (WebSockets) in a modern Rails 8 app using importmap and Stimulus controllers, based on real-world experience.

---

## 1. Prerequisites
- Rails 8.x
- JavaScript managed by importmap (default in Rails 7+)
- Puma server (default, supports WebSockets)
- Stimulus for frontend controllers (optional, but recommended)

---

## 2. Server-Side Setup

### a. Mount Action Cable in `config/routes.rb`
```ruby
mount ActionCable.server => '/cable'
```

### b. Configure Development Environment
In `config/environments/development.rb`, add:
```ruby
config.action_cable.url = "ws://localhost:3000/cable"
config.action_cable.allowed_request_origins = [ /http:\/\/localhost:3000/, /http:\/\/127.0.0.1:3000/ ]
```

---

## 3. Importmap Configuration

In `config/importmap.rb`, ensure:
```ruby
pin "@rails/actioncable", to: "actioncable.esm.js"
```

---

## 4. JavaScript Client Setup

### a. Initialize Action Cable in `app/javascript/application.js`
```javascript
import { createConsumer } from "@rails/actioncable";
window.App ||= {};
window.App.cable = createConsumer();
```

### b. Stimulus Controller Example (`app/javascript/controllers/chat_controller.js`)
- Subscribe to a channel using `window.App.cable.subscriptions.create`
- Handle incoming messages and update the UI

---

## 5. Layout Requirements
- Ensure `<%= javascript_importmap_tags %>` is present in your layout (e.g., `application.html.erb`).
- Add `<%= action_cable_meta_tag %>` if you use Turbo Streams (optional for custom JS clients).
- Provide a meta tag with the current user ID if you stream for users:
  ```erb
  <% if user_signed_in? %>
    <meta name="current-user-id" content="<%= current_user.id %>">
  <% end %>
  ```

---

## 6. Common Troubleshooting

- **WebSocket not connecting?**
  - Do NOT visit `/cable` directly; let the JS client connect.
  - Check the browser Network tab for a WebSocket connection to `/cable`.
  - Ensure `window.App.cable` is defined in the console.
  - Check for JavaScript errors in the browser console.
  - Make sure the correct port and protocol are used in `config.action_cable.url`.
  - Restart the Rails server after config changes.

- **No real-time updates?**
  - Confirm the server log shows `Successfully upgraded to WebSocket`.
  - Ensure your channel is streaming for the correct identifier (e.g., `stream_for current_user`).
  - Make sure your Stimulus controller or JS client is subscribing with the correct identifier.

- **Duplicate or missing messages?**
  - Check your message handler to ensure it displays both user and AI messages if both are present.
  - If your payload nests messages (e.g., `{ message: { ... } }`), flatten or handle accordingly in your JS.

---

## 7. Example: Minimal ChatChannel
```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end
```

---

## 8. Example: Minimal Stimulus Chat Controller
```javascript
// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus";
export default class extends Controller {
  connect() {
    const meta = document.querySelector('meta[name="current-user-id"]');
    this.currentUserId = meta ? meta.getAttribute('content') : null;
    if (window.App && window.App.cable) {
      window.App.cable.subscriptions.create(
        { channel: "ChatChannel", id: this.currentUserId },
        { received: (data) => { /* handle data */ } }
      );
    }
  }
}
```

---

## 9. Final Checklist
- [x] `/cable` is mounted in routes
- [x] Action Cable is pinned in importmap
- [x] Action Cable is initialized in JS
- [x] Allowed origins and URL are set in environment config
- [x] Layout includes importmap tags and user meta tag
- [x] Stimulus/JS controller subscribes to the correct channel
- [x] WebSocket connection appears in browser Network tab

---

## 10. References
- [Action Cable Overview — Rails Guides](https://guides.rubyonrails.org/action_cable_overview.html)
- [StimulusJS](https://stimulus.hotwired.dev/)
- [Importmap for Rails](https://github.com/rails/importmap-rails)

---

If you follow these steps, Action Cable should work reliably for real-time features in your Rails 8 app.
