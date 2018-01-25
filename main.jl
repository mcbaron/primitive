# main.jl
using ProgressMeter
# Include helper functions
include("deps.jl")

in_path = "images/sukii.jpg"
# in_path = "images/lawrence.jpg"
# Constants:
shape = "Triangle"
num_shape = 100
pick_from_n = 12
max_age_of_shape = 10

in_img = loadFloatImage(in_path)

m, n = size(in_img)
bounds = [m, n]

# Initialize the background color to the average of the image.
mean_color = mean(in_img)
canvas = fill(mean_color, size(in_img))

@showprogress 1 "Fitting Shapes..." for i = 1:num_shape
avail_shapes = Array{primitive}(pick_from_n)
avail_canvases = fill(canvas, pick_from_n)
avail_score = Array{Float64}(pick_from_n)
# Generate N random shapes, pick the best one, and start hill climbing
    for j = 1:pick_from_n
        avail_shapes[j] = genRandShape(shape, bounds)
        avail_canvases[j] = applyMask(avail_canvases[j], avail_shapes[j], in_img)
        avail_score[j] = MSE(in_img, avail_canvases[j])
    end
    best_error, s_index = findmin(avail_score)
    # extract the "best" shape
    cur_shape = avail_shapes[s_index]
    # cur_canvas = avail_canvases[s_index]
    # Mutate + Hill Climb
    canvas = hillClimb(canvas, cur_shape, in_img, max_age_of_shape)

end
imshow(canvas)
