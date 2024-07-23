"""
    BusFaultModel <: ComponentModel

Type definition for a short-circuited bus in the power system.

# Fields
- `unfaulted_model_data`: Model data of the original bus component before the fault is applied. This is used to restore the original model data after the fault is cleared.

# Note
The `BusFaultModel` applies a three-phase short circuit with zero fault resistance.
"""
struct BusFaultModel <: ComponentModel
    unfaulted_model_data::ComponentModelData
end
variables(::Type{BusFaultModel}) = ["V", "θ"]
differential_variables(::Type{BusFaultModel}) = []

"""
    update!(out, du, u, model::BusFaultModel, t)

Implements the equations for a `BusFaultModel`.

# Variables

### Algebraic Variables
- `V`: Voltage at the bus (p.u.).
- `θ`: Voltage angle at the bus (rad).

# Equations

``V = 0`

``θ = 0``

Note that setting θ to zero is somewhat arbitrary as the angle disappears from all other node equations when V is zero.
"""
function update!(out, du, u, model::BusFaultModel, t)
    # Extract variables
    (V, θ) = u

    # Set V and θ to zero at the faulted bus
    out[1] = V
    out[2] = θ
end

function make_dynamic_model(net, bus_ind, ::Type{BusFaultModel})
    return BusFaultModel()
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    bus_ind::Int64,
    var_list::Vector{String},
    ::Type{BusFaultModel},
)
    # Extract output vector indexes
    inds = find_variable_indexes(var_list, ["V_$bus_ind", "θ_$bus_ind"])

    return inds
end

function algebraic_equations!(F, vars, states, model::BusFaultModel)
    # Extract variables
    (V, θ) = vars

    # Define equations
    F[1] = V
    F[2] = θ
end

###############################################################################
# BusFault
###############################################################################
"""
    BusFault <: Disturbance

Type definition for a disturbance that applies a 3-phase, bolted, short-circuit fault at a bus in the power system.

# Fields
- `bus_ind`: Index of the bus where the fault is applied
- `t_disturbance`: Time at which the disturbance is applied(s)
- `restart_simulation`: Flag indicating whether the simulation should be restarted after applying the disturbance
"""
struct BusFault <: Disturbance
    bus_ind
    t_disturbance
    restart_simulation

    # Constructor with default value for restart_simulation
    BusFault(bus_ind, t_disturbance; restart_simulation=false) = new(bus_ind, t_disturbance, restart_simulation)
end

"""
    perturb_model!(power_system_model::PowerSystemModel, disturbance::BusFault)

Applies a 3-phase, bolted, short-circuit fault at a bus in the PowerSystemModel.

A `BusFaultModel` is created for the faulted bus and replaces the original model data in the component list.
"""
function perturb_model!(power_system_model::PowerSystemModel, disturbance::BusFault)
    # Get indexes of V and θ at the faulted bus
    bus_ind = disturbance.bus_ind
    (V_ind, θ_ind) = find_variable_indexes(power_system_model.variables, ["V_$bus_ind", "θ_$bus_ind"])

    # Get index of faulted bus model data
    bus_component_model_data_ind = findfirst(n -> n.model isa NodeModel && n.source_ind == disturbance.bus_ind, power_system_model.component_list)
    # Make faulted bus model
    faulted_bus_component_model_data = ComponentModelData(
        bus_ind,
        BusFaultModel(
            power_system_model.component_list[bus_component_model_data_ind]
        ),
        [V_ind, θ_ind],
        [],
        [V_ind, θ_ind]
    )

    # Modify load equations
    power_system_model.component_list[bus_component_model_data_ind] = faulted_bus_component_model_data

end