# deps.jl
using Images, ImageFiltering, ImageTransformations
using ColorVectorSpace, ImageView

type primitive
  center::Vector
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
# Define helper functions

# Load float image
function loadFloatImage(path)
  # return float(channelview(load(path)))
  return load(path)
  # For a NxM image, this returns a 3xNxM Array.
  # To move the color channel to the last dimension:
  # ch2 = cat(3,ch[1,:,:], ch[2,:,:], ch[3,:,:])
  # This reshaping might not be necessary
  # look into permutedims, which makes a new array and is better for adjacent
  #      pixels within a color channel
  # or look into permuteddimsview, which shares memory, and is better
  #      for accessing across color for a single pixel
end

function gen_rand_shape(shape::String, bounds::Vector)
  cvsdiag = norm(bounds)
  center = [rand(1:bounds[1]), rand(1:bounds[2])] #needs to be an Int
  majlen = rand(1:.1:sqrt(cvsdiag)) # granularity of .1 pixel
  minlen = clamp(rand(1:.1:sqrt(cvsdiag)), 10, majlen)
  ang = rand(1:.05:2*π) # granularity of .05 radians

  return P = primitive(center, majlen, minlen, ang, shape)
end

function mk_shape(shape::primitive, canvas_size::Vector)
    # Take in a shape and a tuple of canvas size
    # Return a canvas sized mask with the full shape masked out
    if shape.name == "Triangle"
        return triangle_rasterize(shape, canvas_size)
    elseif shape.name == "Rectangle"
        return rectangle_rasterize(shape, canvas_size)
    elseif shape.name == "Ellipse"
        return ellipse_rasterize(shape, canvas_size)
    elseif shape.name == "Curve"
        return curve_rasterize(shape, canvas_size)
    end
end

function mk_color(shape::primitive, src_img)
    # Take in a shape and a source image
    # calculate fill color as a weighted sum of the colors of pixels in
    # the source image that lie within the shape.
    # uses mk_shape()
    # Return the color as RGB
end

function fill_area(canvas, shape::primitive, color::RGB)
  # Take in a canvas, a shape, and a color.
  # Figure out what pixels on the canvas are under the shape given parameters
  # Create a `canvas` sized mask for the fill
  # Set the color of `canvas` under the mask to the value `color`
  # uses mk_shape()
  # Return the modified canvas
end

function MSE(image, canvas)
  # Take in an image and a canvas
  # Return the Variance between the canvas and the image
  m, n = size(image)

  P = eye(m,n) - (1/sqrt(m*n))*ones(Float64, m, n)

  return P*(image - canvas)*P
end

function mutate_shape(shape::primitive)
    # Take in shape, randomly mutate, and return
    # granularity
    g = 16

    c_offset = [rand(1:g), rand(1:g)]
    maj_offset = rand(1:g)
    min_offset = rand(1:g)
    ang_offset = 2*π*rand(1:2*g)/360

    offset = primitive(c_offset, maj_offset, min_offset, ang_offset, shape.name)
    return shape + offset
end

# Trinagle Specific Functions
function triangle_rasterize(triangle::primitive, bounds::Vector)
    mask = Array{Bool}(bounds[1], bounds[2])

    l = .5*triangle.majlen
    m = .5*triangle.minlen
    v0 = triangle.center + [l*cos(triangle.angle), l*sin(triangle.angle)]
    # v1 is the vector from v0 to the 1st vertex
    v1 = [m*sin(triangle.angle) - 2*l*cos(triangle.angle), m*cos(triangle.angle) - 2*l*sin(triangle.angle)]
    # v2 is the vector from v0 to the 2nd vertex
    v2 = [-m*sin(triangle.angle) - 2*l*cos(triangle.angle), -m*cos(triangle.angle) - 2*l*sin(triangle.angle)]

    for i in 1:bounds[1]
        for j in 1:bounds[2]
            v = [i,j]
            a = (d(v,v2) - d(v0,v2)) / d(v1,v2)
            b = -(d(v,v1) - d(v0,v1)) / d(v1,v2)
            mask[i,j] = (a > 0) & (b > 0) & ((a+b)<1) ? true : false
        end
    end
    return mask
end

# Determinant of concatinated vectors
function d(u, v)
    return u[1]*v[2] - u[2]*v[1]
end

# Rectangle Specific Functions
function rectangle_rasterize(rec::primitive, bounds::Vector)
    mask = Array{Bool}(bounds[1], bounds[2])

    l = .5*rec.majlen
    m = .5*rec.minlen
    # v0 and v2 are along the same diagonal, v1 and v3 are along the same diagonal
    v0 = rec.center + [l*cos(rec.angle) + m*sin(rec.angle), l*sin(rec.angle) + m*cos(rec.angle)]
    v1 = rec.center + [l*cos(rec.angle) - m*sin(rec.angle), l*sin(rec.angle) - m*cos(rec.angle)]
    # v2 = rec.center - [l*cos(rec.angle) - m*sin(rec.angle), l*sin(rec.angle) - m*cos(rec.angle)]
    v3 = rec.center - [l*cos(rec.angle) + m*sin(rec.angle), l*sin(rec.angle) + m*cos(rec.angle)]

    # Make v1 and v3 the vector from v0 to v1 and v3 respectively
    v1 = v1 - v0
    v3 = v3 - v0

    # Use the same change of basis trick as in the triangle interior
    for i in 1:bounds[1]
        for j in 1:bounds[2]
            v = [i,j]
            a = (d(v,v3) - d(v0,v3)) / d(v1,v3)
            b = -(d(v,v1) - d(v0,v1)) / d(v1,v3)
            mask[i,j] = (a > 0) & (b > 0) & (a < 1) & (b < 1) ? true : false
        end
    end
    return mask
end

# Ellipse Specific Functions
function ellipse_rasterize(ellipse::primitive, bounds::Vector)
    mask = Array{Bool}(bounds[1], bounds[2])
    # Use the affine transformation defined by the vertecies of the ellipse
    l = .5*ellipse.majlen
    m = .5*ellipse.minlen

    v0 = ellipse.center + [l*cos(ellipse.angle), l*sin(ellipse.angle)]
    v1 = ellipse.center + [m*sin(ellipse.angle), m*cos(ellipse.angle)]

    # A is a matrix which defines the affine transform from the unit circle to this ellipse.
    A = cat(2,v0, v1)
    # Ainv is the affine transform between this ellipse and the unit circle
    Ainv = inv(A)

    for i in 1:bounds[1]
        for j in 1:bounds[2]
            v = [i,j]
            u = Ainv*(v - ellipse.center)
            mask[i,j] = norm(u) < 1 ? true : false
        end
    end
    return mask
end

# Curve Specific Functions
function curve_rasterize(curve::primitive, bounds::Vector)
    mask = Array{Bool}(bounds[1], bounds[2])
    l = .5*curve.majlen
    m = .5*curve.minlen
    # v0 - v2 are control points (defined as bordering a rectange) for the quadratic bezier curve.
    # v0 and v2 define the endpoints of the curve and lie along the main diagonal
    v0 = curve.center + [l*cos(curve.angle) + m*sin(curve.angle), l*sin(curve.angle) + m*cos(curve.angle)]
    v1 = curve.center + [l*cos(curve.angle) - m*sin(curve.angle), l*sin(curve.angle) - m*cos(curve.angle)]
    v2 = curve.center - [l*cos(curve.angle) - m*sin(curve.angle), l*sin(curve.angle) - m*cos(curve.angle)]

    x = v0 - v1
    t = v0[1] - 2*v1[1]*v2[1]
    if (x[1]*(v2[1] - v1[1]) > 0)
        if (x[2]*(v2[2] - v1[2]) > 0)
            if (abs((v0[2]-2*v[2]+v2[2])/(t*x[1])) > abs(x[2]))
                v0 = v2
                v2 = x + v1
            end
        end
        t = (v0[1] - v1[1]) / t
        r = (1-t)*((1-t)*v0[2]+2*t*v1[2])+t*t*v2[2]
        t = (v0[1]*v2[1]-v1[1]^2)*t / (v0[1] - v1[1])
        x = floor([t+.5, r+.5])
        r = (v1[1] - v0[1])*(t - v0[1]) / (v1[1]-v2[1]) + x[2]
        curve_segment_rasterize(v0, [x[1], floor(r+.5)], x, mask)
        r = (v1[2] - v2[2])*(t-v2[1])/(v1[1]-v2[1]) + v2[2]
        v0 = x
        v1 = [x[1], floor(r+.5)]
    end
    if ((v0[2] - v1[2])*(v2[2] - v1[2]) > 0)

    end
    curve_segment_rasterize(v0, v1, v2, mask)
end

function curve_segment_rasterize(p0::Vector, p1::Vector, p2::Vector, mask::AbstractArray)
    # Plot a quadratic Bezier segment
    s = p2 - p1
    x = p0 - p1
    cur = d(x,s) # Curvature
    # Assert x[1]*s[1] >= 0 & x[2]*s[2] >= 0
    if s'*s > x'*x # begin with the longer part
        p2 = p0
        p0 = s + p1
        cur = -cur
    end
    if cur != 0
        x += s
        x[1] *= s[1] = (p0[1] < p2[1]) ? 1 : -1 # Step along vector
        x[2] *= s[2] = (p0[2] < p2[2]) ? 1 : -1 # Step along vector
        xy = 2*x[1]*x[2]
        x .*= x
        if (cur * s[1] * s[2] < 0) # Negative Curvature
            x = -x
            xy = -xy
            cur = -cur
        end
        dx = 4*s[2]*cur*(p1[1]-p0[1])+x[1]-xy
        dy = 4*s[1]*cur*(p0[2]-p1[2])+x[2]-xy
        x .+= x
        x = Int.(floor.(x))
        err = dx + dy + xy
        while ((dy < 0) & (dx > 0))
            mask[x[1], x[2]] = true
            mask[x[1], x[2]+1] = true
            mask[x[1], x[2]-1] = true
            if (p0 == p2) # We're done
                break
            end
            p1[2] = 2*err < dx
            if (2*err > dy)
                p0[1] += s[1]
                dx -= xy
                err += dy =+ x[2]
            end
            if (p1[2])
                p0[2] += s[2]
                dy -= xy
                err += dx += x[1]
            end
        end
    end
    # plotline(p0, p2)
end
