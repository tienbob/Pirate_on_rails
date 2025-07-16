# Project Specification: Pirate on Rails

## Overview
Pirate on Rails is a fullstack Ruby on Rails web application for streaming anime movies. It features admin-only content management, advanced search and filtering with Elasticsearch, video streaming, tag management, Stripe-powered payments for pro features, and a modern Hotwire/Stimulus UI.

## Features

### User Roles
- **Admin**: Can upload, edit, and tag movies; manage payments; access admin-only UI.
- **User**: Can search, filter, and stream movies; upgrade to pro via Stripe payment for additional features.

### Movie Management
- Movies have: title, description, release date, video file (Active Storage), tags, and is_pro (pro-only flag).
- Admins can upload movies and assign multiple tags.
- Video streaming is supported via the show page.

### Tag System
- Many-to-many relationship between movies and tags. -> support table movie_tag
- Admins can create, edit, and delete tags.
- Users can filter/search movies by tags (multi-select, badge UI).

### Search & Filtering
- Full-text search on movie title, description, and tags using Elasticsearch.
- Advanced filters: search by name, year range, and multiple tags.
- Search UI is modern, compact, and user-friendly (custom JS, badge-based tag selection).

### Payments
- Stripe integration for upgrading users to pro accounts.
- Admins can view/manage payments.
- Users receive a confirmation email/receipt after payment.

### Authentication & Authorization
- Devise for user authentication (sign up, login, etc.).
- Pundit for role-based authorization (admin/user access control).

### UI/UX
- Anime-inspired, modern design with glassmorphism, gradients, and custom fonts.
- Responsive layout using Bootstrap and custom CSS.
- Hotwire (Turbo/Stimulus) for reactive UI and custom JS for tag selection.

### Testing
- RSpec for model and feature tests.
- FactoryBot and Shoulda-Matchers for test data and validation.

## Technical Stack
- Ruby 3.2+, Rails 8+
- PostgreSQL (production) / SQLite (development)
- Elasticsearch 8.x
- Redis (optional, for background jobs)
- Active Storage for video uploads
- Stripe for payments
- Devise & Pundit for authentication/authorization
- Hotwire (Turbo/Stimulus) for frontend interactivity
- Bootstrap for styling

## Setup & Deployment
- See README.md for detailed setup, configuration, and deployment instructions.
- Environment variables and credentials are managed via Rails credentials.
- Elasticsearch must be running for search features.

## Notable Files & Directories
- `app/models/`: Movie, Tag, MovieTag, User, Payment models
- `app/controllers/`: Movies, Tags, Payments, Users controllers
- `app/views/`: All UI, including movies, tags, payments, and layouts
- `app/javascript/controllers/`: Custom JS for search/tag UI (Hotwire convention)
- `spec/`: RSpec tests

## Limitations & Notes
- Only admins can upload/tag movies and manage payments.
- Users must upgrade to pro for certain features (is_pro flag on movies).
- Tag selection and search UI are custom and require JS to function fully.
- For development, SQLite is supported; for production, use PostgreSQL.

## Estimates

### Time Estimate 

| Feature/Task                | Estimated Hours |
|-----------------------------|-----------------|
| Project setup & scaffolding | 4               |
| User authentication (Devise)| 3               |
| Admin/user roles (Pundit)   | 2               |
| Movie CRUD & video upload   | 6               |
| Tag system (UI & backend)   | 5               |
| Search & filters (Elasticsearch) | 6         |
| Payment integration (Stripe)| 5               |
| UI/UX (Bootstrap, anime style, Hotwire) | 8   |
| Testing (RSpec, factories)  | 4               |
| Email/receipt integration   | 2               |
| Deployment & docs           | 2               |
| **Total**                   | **47 hours**    |

*Estimates may vary based on feature changes.*

---
For further details, see the README or contact the project maintainer.
