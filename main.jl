# main.jl
using ProgressMeter
using Statistics
using YAML
# Include helper functions
include("deps.jl")

# Load configuration from YAML file
config_path = "config/image_config.yaml"
config = YAML.load_file(config_path)

canvas = makeResultCanvas(config)

imshow(canvas)
output_filename = "images/$(config["num_shape"])$(config["shape"]).png"
save(output_filename, canvas)
