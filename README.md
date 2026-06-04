# Groop members 
name                 ID                email

1, Peter koru        ATE/1191/15      Peterkoru94@gmail.com
2, Biniyam abel      ATE/8191/15      biniyamabel54@gmail.com
3, Esmael Abdusemed  ATE/9586/15      Ezmirilyan1@gmail.com
4, berekat           ATE/7787/15      berekethergbz@gmail.com

# meals App
Overview
Our project meals App is a Flutter based mobile application that allows users to browse meals by category, save favorite meals, create and manage personal recipes, and apply dietary filters. The application uses Supabase for authentication, database management, and image storage.

The project demonstrates modern Flutter development practices using Riverpod state management, repository architecture, and cloud based backend services

## Features

User Features

User Registration & Login
Google Sign-In (OAuth)
Password Reset via Email
Browse Meals by Category
Search Meals
View Meal Details
Save and Remove Favorites
Create Personal Recipes
Upload Meal Images
Manage Personal Meals
Apply Dietary Filters
Gluten Free
Lactose Free
Vegetarian
Vegan

Admin Features

Manage Categories
Create Categories
Edit Categories
Delete Categories
Manage Public Meals(delete, edit meals)
Upload meal Images
Assign Meals to Multiple Categories

### System Architecture
UI (Screens & Widgets)
        >
Providers (Riverpod State Management)
        >
Repositories
        >
Services
        >
Supabase Backend


Screens Responsible for:
Displaying data
Handling user interaction
Navigation

Providers Responsible for:
Managing application state
Loading data
Error handling
Sharing state across screens

Repositories Responsible for:
Database communication
CRUD operations
Data retrieval

Services Responsible for:
External operations
Authentication
Image uploads

#### Packages Used

flutter riverpod

used to:
Manage application state
Share data between screens
Handle asynchronous data

supabase flutter

Used for:
Authentication
Database access
Storage uploads
OAuth login

image_picker

Used for:
Selecting meal images from device gallery
Capturing images from camera

shared_preferences

Used for:
Local storage
Session-related settings
User persistence

app_links

Used for:
Deep links
Password reset links
OAuth callbacks

google_fonts

Used for:
Custom typography

transparent_image

Used for:
Placeholder images
Smooth image loading

##### Database Structure

Profiles Table

Stores:
User ID
Role
Favorites
Filters

Meals Table

Stores:
id
title
image_url
ingredients
steps
duration
complexity
affordability
scope
user_id
categories

Categories Table

Stores:
id
title
color
gradient_start
gradient_end

###### Authentication Flow

User Login
      >
Supabase Auth
      >
Session Created
      >
AppEntry
      >
SessionGate
      >
Role Check
      >
Admin Dashboard or User Dashboard

