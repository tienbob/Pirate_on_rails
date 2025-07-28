# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#

# Seed tags
tag_names = ["Action", "Comedy", "Drama", "Horror", "Sci-Fi", "Romance", "Thriller", "Documentary", "Fantasy", "Adventure"]
tags = tag_names.map { |name| Tag.find_or_create_by!(name: name, description: "#{name} movies") }

# Seed movies
require 'date'
50.times do |i|
  title = "Movie ##{i+1}"
  description = "This is the description for #{title}. It is a great film in the #{tag_names.sample} genre."
  release_date = Date.today - rand(1000)
  is_pro = [true, false].sample
  movie = Movie.new(title: title, description: description, release_date: release_date, is_pro: is_pro)
  movie.video_file.attach(
    io: File.open(Rails.root.join('movie/sumpoc_12.mp4')),
    filename: 'sumpoc_12.mp4',
    content_type: 'video/mp4'
  )
  movie.save!
  movie.tags << tags.sample(rand(1..3))
end
