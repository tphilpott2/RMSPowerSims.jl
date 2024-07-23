###########################################################################
# Mathematical functions
###########################################################################
# Cartesian to polar conversions
struct phasor
    r::Any
    θ::Any
end

function ptc(r::Union{Float64,Int}, θ::Union{Float64,Int}; deg=false)
    if deg == true
        return r * (cos(pi * θ / 180) + 1im * sin(pi * θ / 180))
    else
        return r * (cos(θ) + 1im * sin(θ))
    end
end

function ctp(c::Union{ComplexF64,Complex{Int64}}; deg=false)
    x = real(c)
    y = imag(c)
    r = sqrt(x^2 + y^2)
    y == 0 && x > 0 ? θ = 0 : nothing
    y == 0 && x < 0 ? θ = pi : nothing
    x == 0 && y > 0 ? θ = pi / 2 : nothing
    x == 0 && y < 0 ? θ = -pi / 2 : nothing
    x > 0 ? θ = atan(y / x) : nothing
    x < 0 && y > 0 ? θ = pi + atan(y / x) : nothing
    x < 0 && y < 0 ? θ = -pi + atan(y / x) : nothing
    if deg == true
        return phasor(r, θ * 180 / pi)
    else
        return phasor(r, θ)
    end
end

function ctp(x::Union{Float64,Int64}, y::Union{Float64,Int64}; deg=false)
    r = sqrt(x^2 + y^2)
    y == 0 && x > 0 ? θ = 0 : nothing
    y == 0 && x < 0 ? θ = pi : nothing
    x == 0 && y > 0 ? θ = pi / 2 : nothing
    x == 0 && y < 0 ? θ = -pi / 2 : nothing
    x > 0 ? θ = atan(y / x) : nothing
    x < 0 && y > 0 ? θ = pi + atan(y / x) : nothing
    x < 0 && y < 0 ? θ = -pi + atan(y / x) : nothing
    if deg == true
        return phasor(r, θ * 180 / pi)
    else
        return phasor(r, θ)
    end
end

# dq0 transformations
function dq_transform(phsr::ComplexF64, δ::Float64)
    phsr_dq = phsr / (cos(δ - pi / 2) + 1im * sin(δ - pi / 2))
    return (real(phsr_dq), imag(phsr_dq))
end

###########################################################################
# Search for generators and loads connected to a bus
###########################################################################
function get_gens_connected_to_bus(net::Dict{String,Any}, bus_ind::Int64)
    connected_gen_indexes = []
    for (g, gen) in net["gen"]
        gen["gen_bus"] == bus_ind ? push!(connected_gen_indexes, gen["index"]) : nothing
    end
    return connected_gen_indexes
end

function get_loads_connected_to_bus(net::Dict{String,Any}, bus_ind::Int64)
    connected_load_indexes = []
    for (l, load) in net["load"]
        load["load_bus"] == bus_ind ? push!(connected_load_indexes, load["index"]) : nothing
    end
    return connected_load_indexes
end

has_gen(net::Dict{String,Any}, bus_ind::Int64) = bus_ind ∈ [gen["gen_bus"] for (g, gen) in net["gen"]]

has_load(net::Dict{String,Any}, bus_ind::Int64) = bus_ind ∈ [load["load_bus"] for (l, load) in net["load"]]

has_avr(gen::Dict{String,Any}) = any(controller["model_type"] <: AVRModel for controller in values(gen["dynamic_model"]["controllers"]))

has_gov(gen::Dict{String,Any}) = any(controller["model_type"] <: GovernorModel for controller in values(gen["dynamic_model"]["controllers"]))

pad_with_element_index(variable_name::String, index) = "$(variable_name)_$(index)"

