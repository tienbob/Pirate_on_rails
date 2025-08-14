# Authentication Workflow Documentation

## Overview
The authentication workflow in our application is powered by Devise, a flexible authentication solution for Rails. It provides a comprehensive set of features for user authentication, including secure password management, session handling, and optional modules for additional functionality.

---

## Key Features of Devise

### 1. **User Authentication**
- Devise ensures secure user authentication by hashing passwords using bcrypt.
- Users can log in with their email and password.
- Sessions are managed securely to prevent unauthorized access.

### 2. **Password Recovery**
- Users can request a password reset if they forget their password.
- Devise generates a secure, time-limited token and sends it to the user's email.
- The token is hashed and stored in the database for verification.
- Users can reset their password using the token.

### 3. **Remember Me**
- The "Remember Me" feature allows users to stay logged in across sessions.
- A secure token is generated and stored in a cookie.
- The token is validated on subsequent visits to authenticate the user.

### 4. **Role-Based Access Control**
- User roles (`admin`, `pro`, `free`) are managed in the `User` model.
- Role-based methods (`admin?`, `pro?`, `free?`) are used to enforce access control in controllers and views.

### 5. **Timeoutable**
- The `:timeoutable` module logs users out after a period of inactivity.
- This enhances security by preventing unauthorized access to idle sessions.

### 6. **Optional Modules**
- Devise supports additional modules such as `:confirmable`, `:lockable`, and `:trackable` for advanced authentication workflows.

---

## Workflow Details

### 1. **User Registration**
- Users can register using their name, email, and password.
- Passwords must meet the minimum length requirement (6 characters).
- The `set_default_role` callback assigns the `free` role to new users.

### 2. **User Login**
- Users log in with their email and password.
- Devise validates the credentials and creates a session for the user.
- The `current_user` helper provides access to the logged-in user's details.

### 3. **Password Reset**
- Users can request a password reset by providing their email.
- Devise generates a secure token and sends it to the user's email.
- The token is valid for a limited time and is hashed in the database.
- Users can reset their password using the token.

### 4. **Session Management**
- Devise manages user sessions securely.
- The `:timeoutable` module logs users out after a period of inactivity.
- The "Remember Me" feature allows users to stay logged in across sessions.

### 5. **Role-Based Access Control**
- The `User` model includes methods to check user roles (`admin?`, `pro?`, `free?`).
- Controllers use `before_action` filters to enforce role-based access control.
  - Example: `require_admin` ensures only admins can access certain actions.

### 6. **Account Management**
- Users can update their account details, including email and password.
- Admins can manage user accounts, including creating, updating, and deleting users.
- Cache is cleared when user data is updated to ensure consistency.

---

## Security Measures
- Passwords are hashed using bcrypt before being stored in the database.
- Tokens for password reset and "Remember Me" are securely hashed and time-limited.
- Sessions are managed securely to prevent unauthorized access.
- Role-based access control ensures users can only access authorized resources.

---

## Customizations
- The `set_default_role` callback in the `User` model assigns the `free` role to new users.
- Role-based methods (`admin?`, `pro?`, `free?`) simplify access control logic.
- Scopes in the `User` model (`active`, `pro_users`, `free_users`, `admins`) enhance querying capabilities.

---

## Future Improvements
- Enable the `:confirmable` module to require email confirmation during registration.
- Implement the `:lockable` module to lock accounts after multiple failed login attempts.
- Add multi-factor authentication (MFA) for enhanced security.

---

This document provides a detailed overview of the authentication workflow in our application. For further details, refer to the `User` model and `UsersController` files.
