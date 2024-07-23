"""
    ConstantMechanicalPower <: GovernorModel

Type definition for constant mechanical power of a synchronous machine.

# Fields
- `Pm0`: Value of the mechanical power (p.u. on generator MVA base).
"""
struct ConstantMechanicalPower <: ControllerModel
    Pm0::Float64
end

variables(::Type{ConstantMechanicalPower}) = ["Tm"]
differential_variables(::Type{ConstantMechanicalPower}) = []

"""
    update!(out, du, u, model::ConstantMechanicalPower, t)

Implements the equations of a constant mechanical power model for a synchronous generator.

# Variables

### Algebraic Variables

- `Tm`: Mechanical power (p.u. on generator MVA base).

### External variables

- `ω`: Angular velocity of the generator (rad/s).

# Equations

``T_m = P_{m0} / ω``

"""
function update!(out, du, u, model::ConstantMechanicalPower, t)
    # Extract parameters directly from the model
    Pm0 = model.Pm0

    # Extract variables from input vector 'u' and 'du'
    (Tm, ω) = u

    # Differential Equations
    out[1] = Tm - Pm0 / ω
end

#######################################################################
# GENERATE SYSTEM EQUATIONS
#######################################################################

function make_dynamic_model(net::Dict{String,Any}, gen_ind::Int64, ::Type{ConstantMechanicalPower})
    return ConstantMechanicalPower(net["gen"]["$gen_ind"]["dynamic_model"]["parameters"]["Tm0"])
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    gen_ind::Int64,
    var_list::Vector{String},
    ::Type{ConstantMechanicalPower},
)
    # Extract generator and bus_ind
    gen = net["gen"]["$gen_ind"]

    # Find indexes of machine variables
    variable_indexes = find_variable_indexes(var_list, pad_with_element_index.(["Tm", "ω"], gen_ind))
    inds_out = [variable_indexes[1]]
    inds_du = []
    inds_u = variable_indexes

    return inds_out, inds_du, inds_u
end

"""
    generate_ic!(net, gen_ind, ::Type{ConstantMechanicalPower})

Calculates initial conditions of a constant mechanical power model for a synchronous generator.

# Arguments
- `net`: Power system data in network data dictionary format.
- `gen_ind`: Index of the generator in the network data dictionary.
- `::Type{ConstantMechanicalPower}`: Type of constant mechanical power model.

# Equations

``Tm = Tm0``

``Pm0 = Tm0``

# Note

The initial value of the mechanical torque, `Tm0`, is calculated during the initialisation of the SynchronousGeneratorModel that the model is connected to.
"""
function generate_ic!(net, gen_ind, ::Type{ConstantMechanicalPower})
    return DataFrame(
        :names => pad_with_element_index("Tm", gen_ind),
        :values => [net["gen"]["$gen_ind"]["dynamic_model"]["parameters"]["Tm0"]],
    )
end

#######################################################################
# RECALCULATE STATE
#######################################################################
function algebraic_equations!(F, vars, states, model::ConstantMechanicalPower)
    # Extract parameters directly from the model
    Pm0 = model.Pm0
    # Extract algebraic variables
    Tm = vars[1]
    # Extract state variables
    ω = states[1]
    # Differential Equations
    F[1] = Tm - Pm0 / ω
end
