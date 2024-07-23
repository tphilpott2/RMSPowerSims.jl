"""
    COIReferenceFrequency <: ComponentModel

Type definition for the center of inertia reference frequency.

# Fields
- `Mt`: Total inertia constant of the system.
- `M_vec`: Vector of inertia constants of each generator.
"""
struct COIReferenceFrequency <: ComponentModel
    Mt
    M_vec
end

# info functions
variables(::Type{COIReferenceFrequency}) = ["ω_coi"]
differential_variables(::Type{COIReferenceFrequency}) = []

"""
    update!(out, du, u, model::COIReferenceFrequency, t)

Implements the algebraic equations for the center of inertia reference frequency.

Model based on P. W. Sauer and M. A. Pai, "Power System Dynamics and Stability", Upper Saddle River, NJ: Prentice Hall, 1998.

# Variables
### Algebraic Variables
- `ω_coi`: Center of inertia reference frequency (rad/s).

# Equations

``ω_{coi} + \\frac{1}{M_t} \\sum_{i=1}^{n} M_i ω_i = 0``

where

``M_i = \\frac{2H_i}{\\omega_s}``

and

``M_t = \\sum_{i=1}^{n} M_i``

# Note
- COIReferenceFrequency model performance has not been verified against any other simulation software.
"""
function update!(out, du, u, model::COIReferenceFrequency, t)
    # Extract parameters directly from the model
    Mt, M_vec = model.Mt, model.M_vec

    # Extract variables from input vector 'u' and 'du'
    ω_coi = u[1]
    ω = u[2:end]

    # Equations
    out[1] = -ω_coi + (1 / Mt) * sum([M_vec[i] * ω[i] for i in eachindex(ω)])
end

function make_dynamic_model(net::Dict{String,Any}, nothing, ::Type{COIReferenceFrequency})
    # Extract inertia constants of generators
    num_gens = length(keys(net["gen"]))
    ωs = net["dynamic_model_parameters"]["ωs"]
    M_vec = [(2 * net["gen"]["$num_gens"]["dynamic_model"]["parameters"]["H"]) / ωs for gen_ind = 1:num_gens]

    # Calculate total inertia
    Mt = sum(M_vec)

    # Define model
    ω_coi_model = COIReferenceFrequency(Mt, M_vec)
    return ω_coi_model
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    nothing,
    var_list::Vector{String},
    ::Type{COIReferenceFrequency},
)
    # Get indexes of ω for each generator
    ω_inds = find_all_variable_indexes(var_list, "ω")

    # Define index pointers (ω_coi is defined as always 1)
    inds_out = [1]
    inds_du = []
    inds_u = ω_inds

    return inds_out, inds_du, inds_u
end
