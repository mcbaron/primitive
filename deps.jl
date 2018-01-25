# deps.jl
using Luxor, Colors, FileIO, ImageView
using ColorVectorSpace

type primitive
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
    return (Images.Gray.(load(path)) .> 0.5)
end


function genRandShape(shape::String, bounds::Vector)
    cvsdiag = norm(bounds)
    center = randompoint(1, 1, bounds[1], bounds[2]) # needs to be an Int
    majlen = rand(1:.1:cvsdiag) # granularity of .1 pixel
    minlen = clamp(rand(1:.1:cvsdiag), 10, majlen)
    ang = rand(1:.05:2*π) # granularity of .05 radians

    return P = primitive(center, majlen, minlen, ang, shape)
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
    return canvas += c_fill .* Float64.(mask)
end

function MSE(image, canvas)
    # Take in an image and a canvas
    # Return the Variance between the canvas and the image
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
