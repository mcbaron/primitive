# deps.jl
using Luxor, Colors, FileIO, ImageView
using ColorVectorSpace
using Base.Threads

struct primitive
    center::Point
    majlen::Float64
    minlen::Float64
    angle::Float64
    name::String
end

import Base.+
function Base.:+(a::primitive, b::primitive)
    center = a.center + b.center
    maj = a.majlen + b.majlen
    min = a.minlen + b.minlen
    ang = a.angle + b.angle

    primitive(center, maj, min, ang, a.name)
end

import Base.copy
function Base.:copy(a::primitive)
    b = primitive(a.center, a.majlen, a.minlen, a.angle, a.name)
    return b
end
# Define helper functions

# Load float image
function loadFloatImage(path)
    # return float(channelview(load(path)))
    return load(path)
end

# Load bit (binary) image
function loadBitImage(path)
    return (Gray.(load(path)) .> 0.5)
end


function genRandShape(shape::String, bounds::Vector)
    cvsdiag = norm(bounds)
    center = randompoint(1, 1, bounds[1], bounds[2]) # needs to be an Int
    majlen = rand(1:.1:cvsdiag) # granularity of .1 pixel
    minlen = clamp(rand(1:.1:cvsdiag), 10, majlen)
    ang = rand(1:.05:2*π) # granularity of .05 radians

    return primitive(center, majlen, minlen, ang, shape)
end

function makeShape(shape::primitive, canvas_size::Vector)
    # Take in a shape and a tuple of canvas size
    # Return a canvas sized mask with the full shape masked out
    if shape.name == "Triangle"
        return triangleRasterize(shape, canvas_size)
    elseif shape.name == "Rectangle"
        return rectangleRasterize(shape, canvas_size)
    elseif shape.name == "Ellipse"
        return ellipseRasterize(shape, canvas_size)
    elseif shape.name == "Curve"
        return curveRasterize(shape, canvas_size)
    else
        error("Invalid shape name: $(shape.name)")
    end
end

function applyMask(canvas, shape::primitive, src_img)
    # Take in a canvas, a shape, and the source image.
    m, n = size(src_img)
    # Figure out what pixels on the canvas are under the shape given parameters
    mask = makeShape(shape, [m,n])
    # calculate fill color as a weighted sum of the colors of pixels in
    # the source image that lie within the shape.
    color = mean(src_img[Bool.(mask)])
    # Set the color of `canvas` under the mask to the value `color`
    # extract the mean color under the mask
    offset = mean(canvas[Bool.(mask)])
    c_fill = color - offset
    masked_canvas = copy(canvas)
    return masked_canvas += c_fill .* Float64.(mask)
end

function MSE(image, canvas)
    # Take in an image and a canvas
    # Return the MSE between the canvas and the image
    h = (image - canvas)[:]
    return sum([red.(h)'*red.(h), green.(h)'*green.(h), blue.(h)'*blue.(h)])
end

function mutateShape(shape::primitive)
    # Take in shape, randomly mutate, and return
    # granularity
    g = 16

    c_offset = Point(rand(-g:g), rand(-g:g))
    maj_offset = rand(-g:g)
    min_offset = rand(-g:g)
    ang_offset = 2*π*rand(0:2*g)/360

    offset = primitive(c_offset, maj_offset, min_offset, ang_offset, shape.name)
    return shape + offset
end

# Trinagle Specific Functions
function triangleRasterize(tri::primitive, bounds::Vector)
    Drawing(bounds[2], bounds[1], "mask.png")
    background("black")
    sethue("white")

    v0, v1, v2 = ngon(tri.center, tri.minlen, 3, tri.angle, vertices=true)
    poly([v0 + tri.majlen - tri.minlen, v1, v2], :fill)
    finish()
    return loadBitImage("mask.png")
end

# Rectangle Specific Functions
function rectangleRasterize(rec::primitive, bounds::Vector)
    Drawing(bounds[2], bounds[1], "mask.png")
    background("black")
    sethue("white")

    rotate(rec.angle)
    translate(rec.center)
    rect(O, rec.majlen, rec.minlen, :fill)
    finish()
    return loadBitImage("mask.png")
end

# Ellipse Specific Functions
function ellipseRasterize(ellip::primitive, bounds::Vector)
    Drawing(bounds[2], bounds[1], "mask.png")
    background("black")
    sethue("white")

    rotate(ellip.angle)
    translate(ellip.center)
    ellipse(O, ellip.majlen, ellip.minlen, :fill)
    finish()
    return loadBitImage("mask.png")
end

# Curve Specific Functions
function curveRasterize(cve::primitive, bounds::Vector)
    Drawing(bounds[2], bounds[1], "mask.png")
    background("black")

    v0, v1, v2 = ngon(cve.center, cve.majlen, 3, cve.angle, vertices=true)
    sethue("white")
    setline(3)
    arc2r(v0, v1, v2, :stroke)
    finish()
    return loadBitImage("mask.png")
end

# Hill Climbing
function hillClimb(canvas, shape::primitive, image, max_age::Int)
    best_canvas = copy(canvas)
    best_error = Threads.Atomic{Float64}(MSE(image, best_canvas))
    step = 0

    Threads.@threads for age = 0:max_age
        new_shape = mutateShape(shape)
        new_canvas = applyMask(canvas, new_shape, image)
        new_error = MSE(image, new_canvas)
        if new_error < best_error.value
            Threads.atomic_add!(best_error, new_error - best_error.value)
            best_canvas = new_canvas
            age = -1
            shape = new_shape
        end
        step += 1
    end
    return best_canvas
end


function makeResultCanvas(config)
    # Extract values from the config dictionary
    shape = get(config, "shape", "Ellipse")
    num_shape = get(config, "num_shape", 25)
    pick_from_n = get(config, "pick_from_n", 12)
    max_age_of_shape = get(config, "max_age_of_shape", 15)
    in_path = get(config, "in_path", "images/640px-pencils.jpg")

    in_img = loadFloatImage(in_path)

    m, n = size(in_img)
    bounds = [m, n]

    # Initialize the background color to the average of the image.
    mean_color = mean(in_img)
    global canvas = fill(mean_color, size(in_img))

    @showprogress 1 "Fitting Shapes..." for i = 1:num_shape
        avail_shapes = Array{primitive}(undef, pick_from_n)
        avail_canvases = fill(canvas, pick_from_n)
        avail_score = Array{Float64}(undef, pick_from_n)
        
        # Generate N random shapes, pick the best one, and start hill climbing
        Threads.@threads for j = 1:pick_from_n
            avail_shapes[j] = genRandShape(shape, bounds)
            avail_canvases[j] = applyMask(avail_canvases[j], avail_shapes[j], in_img)
            avail_score[j] = MSE(in_img, avail_canvases[j])
        end
        
        best_error, s_index = findmin(avail_score)
        # extract the "best" shape
        cur_shape = avail_shapes[s_index]
        cur_canvas = avail_canvases[s_index]
        # Mutate + Hill Climb
        global canvas = hillClimb(canvas, cur_shape, in_img, max_age_of_shape)
    end
        return canvas
end
