# Pirate on Rails

An anime-inspired movie streaming platform built with Ruby on Rails, featuring admin-only content management, advanced search with Elasticsearch, video streaming, tag management, Stripe-powered payments, and a modern Hotwire UI.

## Requirements

- Ruby 3.2+
- Rails 8+
- PostgreSQL or SQLite (default: SQLite)
- Elasticsearch 8.x
- Redis 

## Setup

1. **Clone the repo:**
   ```sh
   git clone https://github.com/tienbob/Pirate_on_rails.git
   cd Pirate_on_rails
   ```
2. **Install dependencies:**
   ```sh
   bundle install
   yarn install
   ```
3. **Set up the database:**
   ```sh
   rails db:setup
   # or, for existing DB
   rails db:migrate
   rails db:seed
   ```
4. **Configure credentials:**
   - Edit `config/credentials.yml.enc` for secrets (Stripe keys, etc.)
   - Ensure `config/master.key` is present
5. **Start Elasticsearch:**
   - Manual: Run `elasticsearch.bat` from your ES install directory
   - Docker: 
     ```sh
     docker run -d --name elasticsearch -p 9200:9200 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:8.13.4
     ```
   - Visit http://localhost:9200 to verify
6. **Start the Rails server:**
   ```sh
   bin/rails server
   ```

## Running the Test Suite

```sh
bundle exec rspec
```
Specs are located in `spec/`. FactoryBot and Shoulda-Matchers are used for model specs.

## Services

- **Active Storage:** For video uploads/streaming
- **Elasticsearch:** For advanced movie search/filtering
- **Stripe:** For payment and pro account upgrades
- **Devise:** For authentication
- **Pundit:** For authorization
- **Hotwire:** For modern, reactive UI

## Deployment

1. Set environment variables and credentials for production (see `config/credentials.yml.enc`).
2. Ensure Elasticsearch and your database are running in production.
3. Precompile assets:
   ```sh
   RAILS_ENV=production bin/rails assets:precompile
   ```
4. Run migrations:
   ```sh
   RAILS_ENV=production bin/rails db:migrate
   ```
5. Start the server:
   ```sh
   RAILS_ENV=production bin/rails server
   ```

## Notes

- Admin users can upload/tag movies and manage payments.
- Users can search, filter, and stream movies. Pro features require payment.
- Tag selection and search UI are powered by custom JS in `app/javascript/controllers/`.
- For development, you can use SQLite; for production, use PostgreSQL.

---
For questions or contributions, open an issue or PR on GitHub.
