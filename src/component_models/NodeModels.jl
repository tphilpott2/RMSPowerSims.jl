"""
    GenConnected

Type indicating whether a generator is connected to a node.

See subtypes `HasGen` and `NoGen`.
"""
abstract type GenConnected end

"""
    LoadConnected

Type indicating whether a load is connected to a node.

See subtypes `HasLoad` and `NoLoad`.
"""
abstract type LoadConnected end

"""
    HasGen <: GenConnected

Type indicating that a generator is connected to a load.
"""
struct HasGen <: GenConnected end

"""
    NoGen <: GenConnected

Type indicating that no generator is connected to a load.
"""
struct NoGen <: GenConnected end
"""
    HasLoad <: LoadConnected

Type indicating that a load is connected to a load.
"""
struct HasLoad <: LoadConnected end
"""
    NoLoad <: LoadConnected

Type indicating that no load is connected to a load.
"""
struct NoLoad <: LoadConnected end

"""
    NodeModel{G<:GenConnected,L<:LoadConnected} <: ComponentModel

Type definition for a node in a power system.

# Fields
- `local_i`: Index of the node in the reduced admittance matrix
- `n_connections`: Number of branches connected to the node
- `Y_mag`: Vector containing magnitudes of the reduced admittance matrix (p.u. on system base)
- `α`: Vector containing angles of the reduced admittance matrix (rad)
- `n_gens`: Number of generators connected to the node
- `n_loads`: Number of loads connected to the node

# Note
- Y_mag and α are defined as vectors instead of matrices to reduce memory usage. This leverages the diagonal nature of the admittance matrix.
"""
struct NodeModel{G<:GenConnected,L<:LoadConnected} <: ComponentModel
    local_i::Int64
    n_connections::Int64
    Y_mag::Vector{Float64}
    α::Vector{Float64}
    n_gens::Int64
    n_loads::Int64
end

variables(::Type{NodeModel}) = ["V", "θ"]
variables(::Type{NodeModel{G,L}}) where {G,L} = variables(NodeModel)
differential_variables(::Type{NodeModel}) = []
differential_variables(::Type{NodeModel{G,L}}) where {G,L} = differential_variables(NodeModel)

function update!(out, du, u, model::NodeModel{NoGen,NoLoad}, t)
    # Extract parameters directly from the model
    i, n_connections, Y_mag, α, n_gens, n_loads = model.local_i, model.n_connections, model.Y_mag, model.α, model.n_gens, model.n_loads

    # Extract variables
    (V, θ) = (u[1:n_connections], u[n_connections+1:2*n_connections])

    # Extract variables from input vector 'u' and 'du'
    out[1] =
        V[i] * sum([V[k] * Y_mag[k] * cos(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
    out[2] =
        V[i] * sum([V[k] * Y_mag[k] * sin(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
end
function update!(out, du, u, model::NodeModel{HasGen,NoLoad}, t)
    # Extract parameters directly from the model
    i, n_connections, Y_mag, α, n_gens, n_loads = model.local_i, model.n_connections, model.Y_mag, model.α, model.n_gens, model.n_loads

    # Extract variables
    (V, θ) = (u[1:n_connections], u[n_connections+1:2*n_connections])
    (Pg, Qg) = (u[2*n_connections+1:2*n_connections+n_gens], u[2*n_connections+n_gens+1:2*n_connections+2*n_gens])

    # Extract variables from input vector 'u' and 'du'
    out[1] =
        sum(Pg) -
        V[i] * sum([V[k] * Y_mag[k] * cos(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
    out[2] =
        sum(Qg) -
        V[i] * sum([V[k] * Y_mag[k] * sin(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
end
function update!(out, du, u, model::NodeModel{NoGen,HasLoad}, t)
    # Extract parameters directly from the model
    i, n_connections, Y_mag, α, n_gens, n_loads = model.local_i, model.n_connections, model.Y_mag, model.α, model.n_gens, model.n_loads

    # Extract variables
    (V, θ) = (u[1:n_connections], u[n_connections+1:2*n_connections])
    (Pd, Qd) = (u[2*n_connections+1:2*n_connections+n_loads], u[2*n_connections+n_loads+1:2*n_connections+2*n_loads])

    # Extract variables from input vector 'u' and 'du'
    out[1] =
        -sum(Pd) -
        V[i] * sum([V[k] * Y_mag[k] * cos(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
    out[2] =
        -sum(Qd) -
        V[i] * sum([V[k] * Y_mag[k] * sin(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
end

"""
    update!(out, du, u, model::NodeModel{G,L}, t)

Implements the algebraic equations for a node in a power system.

Model based on P. W. Sauer and M. A. Pai, "Power System Dynamics and Stability", Upper Saddle River, NJ: Prentice Hall, 1998.

# Variables
### Algebraic Variables
- `V`: Voltage magnitude (p.u. on system base)
- `θ`: Voltage angle (rad)

### External Variables
- `Pg_i` : Active power output of i = 1:n_gen connected generators (p.u. on system base)
- `Qg_i` : Reactive power output of i = 1:n_gen connected generators (p.u. on system base)
- `Pd_i` : Active power output of i = 1:n_load connected loads (p.u. on system base)
- `Qd_i` : Reactive power output of i = 1:n_load connected loads (p.u. on system base)

# Equations

`` 0 = \\sum_{k=1}^{n_gens}P_{gk} - \\sum_{k=1}^{n_loads}P_{dk} - \\sum_{k=1}^{n_connections} |V_i| |V_k| Y_{mag,k} cos(\\theta_i - \\theta_k - \\alpha_{k})
``

`` 0 = \\sum_{k=1}^{n_gens}Q_{gk} - \\sum_{k=1}^{n_loads}Q_{dk} - \\sum_{k=1}^{n_connections} |V_i| |V_k| Y_{mag,k} sin(\\theta_i - \\theta_k - \\alpha_{k})
``
"""
function update!(out, du, u, model::NodeModel{HasGen,HasLoad}, t)
    # Extract parameters directly from the model
    i, n_connections, Y_mag, α, n_gens, n_loads = model.local_i, model.n_connections, model.Y_mag, model.α, model.n_gens, model.n_loads

    # Extract variables
    (V, θ) = (u[1:n_connections], u[n_connections+1:2*n_connections])
    (Pg, Qg) = (u[2*n_connections+1:2*n_connections+n_gens], u[2*n_connections+n_gens+1:2*n_connections+2*n_gens])
    (Pd, Qd) = (u[2*n_connections+2*n_gens+1:2*n_connections+2*n_gens+n_loads], u[2*n_connections+2*n_gens+n_loads+1:2*n_connections+2*n_gens+2*n_loads])

    # Extract variables from input vector 'u' and 'du'
    out[1] =
        sum(Pg) - sum(Pd) -
        V[i] * sum([V[k] * Y_mag[k] * cos(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
    out[2] =
        sum(Qg) - sum(Qd) -
        V[i] * sum([V[k] * Y_mag[k] * sin(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
end

function make_dynamic_model(net::Dict{String,Any}, bus_ind::Int64, ::Type{NodeModel})
    # Extract bus from network
    bus = net["bus"]["$bus_ind"]
    i = bus["index"]

    # Extract admittances of connected branches
    Y_row = net["Y"][i, :]
    non_zero_indices = findall(x -> x != 0, Y_row)
    Y_mag_row = abs.(Y_row[non_zero_indices])
    α_row = angle.(Y_row[non_zero_indices])

    # Get index of bus in reduced list and number of connections
    local_i = findfirst(isequal(i), non_zero_indices)
    n_connections = length(non_zero_indices)

    # Extract connected generators and loads
    gen_inds = get_gens_connected_to_bus(net, bus_ind)
    load_inds = get_loads_connected_to_bus(net, bus_ind)

    # Return NodeModel
    return NodeModel{
        length(gen_inds) == 0 ? NoGen : HasGen,
        length(load_inds) == 0 ? NoLoad : HasLoad
    }(
        local_i, n_connections, Y_mag_row, α_row, length(gen_inds), length(load_inds)
    )
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    bus_ind::Int64,
    var_list::Vector{String},
    ::Type{NodeModel},
)
    # Extract output vector indexes
    V_inds = find_all_variable_indexes(var_list, "V")
    θ_inds = find_all_variable_indexes(var_list, "θ")
    inds_out = [V_inds[bus_ind], θ_inds[bus_ind]]

    # Extract connected buses
    Y_row = net["Y"][bus_ind, :]
    non_zero_indices = findall(x -> x != 0, Y_row)

    # Extract connected generators and loads
    gen_inds = get_gens_connected_to_bus(net, bus_ind)
    load_inds = get_loads_connected_to_bus(net, bus_ind)

    # Extract input vector indexes
    inds_u = [
        V_inds[non_zero_indices]
        θ_inds[non_zero_indices]
        find_variable_indexes(var_list, ["Pg_$gen_ind" for gen_ind in gen_inds])
        find_variable_indexes(var_list, ["Qg_$gen_ind" for gen_ind in gen_inds])
        find_variable_indexes(var_list, ["Pd_$load_ind" for load_ind in load_inds])
        find_variable_indexes(var_list, ["Qd_$load_ind" for load_ind in load_inds])
    ]

    return inds_out, inds_u
end

function algebraic_equations!(F, vars, states, model::NodeModel)
    # Extract parameters directly from the model
    i, n_connections, Y_mag, α, n_gens, n_loads = model.local_i, model.n_connections, model.Y_mag, model.α, model.n_gens, model.n_loads

    # Extract variables
    (V, θ) = (vars[1:n_connections], vars[n_connections+1:2*n_connections])
    if n_gens > 0
        (Pg, Qg) = (vars[2*n_connections+1:2*n_connections+n_gens], vars[2*n_connections+n_gens+1:2*n_connections+2*n_gens])
    else
        (Pg, Qg) = ([0], [0])
    end

    if n_loads > 0
        (Pd, Qd) = (vars[2*n_connections+2*n_gens+1:2*n_connections+2*n_gens+n_loads], vars[2*n_connections+2*n_gens+n_loads+1:2*n_connections+2*n_gens+2*n_loads])
    else
        (Pd, Qd) = ([0], [0])
    end

    # Define equations
    F[1] =
        sum(Pg) - sum(Pd) -
        V[i] * sum([V[k] * Y_mag[k] * cos(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
    F[2] =
        sum(Qg) - sum(Qd) -
        V[i] * sum([V[k] * Y_mag[k] * sin(θ[i] - θ[k] - α[k]) for k = 1:n_connections])
end
