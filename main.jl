# main.jl
using Images, FileIO, ImageView, Colors, ImageFiltering
using ProgressMeter
# Include helper functions
include("deps.jl")

in_path = "images/sukii.jpg"
# in_path = "images/lawrence.jpg"
# Constants:
shape = "Triangle"
num_shape = 250
pick_from_n = 12
mutations_per_shape = 10

in_img = loadFloatImage(in_path)

m, n = size(in_img)
bounds = [m, n]

# Initialize the background color to the average of the image.
mean_color = mean(in_img)
canvas = fill(mean_color, size(in_img))

avail_shapes = Array{primitive}(pick_from_n)
avail_masks = fill(canvas, pick_from_n)
avail_score = Array{Float64}(pick_from_n)
@showprogress 1 "Shapes..." for i = 1:num_shape
# Generate N random shapes, pick the best one, and start hill climbing
    for j = 1:pick_from_n
        avail_shapes[j] = genRandShape(shape, bounds)
        avail_masks[j] = applyMask(avail_masks[j], avail_shapes[j], in_img)
        avail_score[j] = MSE(in_img, avail_masks[j])
    end
    best_error, s_index = findmin(avail_score)
    # extract the "best" shape
    cur_shape = avail_shapes[s_index]
    cur_canvas = avail_masks[s_index]
    # Let the shape mutate
    for k = 1:mutations_per_shape
        new_shape = mutateShape(cur_shape)
        new_canvas = applyMask(cur_canvas, new_shape, in_img)
        while MSE(in_img, new_canvas) >= best_error
            new_shape = mutateShape(cur_shape)
            new_canvas = applyMask(cur_canvas, new_shape, in_img)
        end # Don't let the mutations walk down the hill
        best_error = MSE(in_img, new_canvas)
        cur_shape = copy(new_shape)
        cur_canvas = copy(new_canvas)
    end
    canvas = copy(cur_canvas)
    # imshow(canvas)
end
imshow(canvas)
