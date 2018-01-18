# main.jl
using Images, FileIO, ImageView, Colors, ImageFiltering
# Include helper functions
include("deps.jl")

in_path = "images/sukii.jpg"
# in_path = "images/lawrence.jpg"

in_img = loadFloatImage(in_path)

m, n = size(in_img)
canvas = zeros(size(in_img))

# Initialize the background color to the average of the image.
mean_color = mean(in_img)
