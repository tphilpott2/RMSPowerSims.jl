"""
    ConstantExcitation <: AVRModel

Type definition for constant excitation of a synchronous machine.

# Fields
- `Efd0`: Value of the field voltage.
"""
struct ConstantExcitation <: ControllerModel
    Efd0
end

variables(::Type{ConstantExcitation}) = ["Efd"]
differential_variables(::Type{ConstantExcitation}) = []

"""
    update!(out, du, u, model::ConstantExcitation, t)

Implements the equations of a constant excitation model for a synchronous generator.


# Variables

- `Efd`: Field voltage.

# Equations

``E_{fd} = E_{fd0}``

"""
function update!(out, du, u, model::ConstantExcitation, t)
    # Extract parameters directly from the model
    Efd0 = model.Efd0

    # Extract variables from input vector 'u' and 'du'
    Efd = u[1]

    # Differential Equations
    out[1] = Efd - Efd0
end

function make_dynamic_model(net::Dict{String,Any}, gen_ind::Int64, ::Type{ConstantExcitation})
    return ConstantExcitation(net["gen"]["$gen_ind"]["dynamic_model"]["parameters"]["Efd0"])
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    gen_ind::Int64,
    var_list::Vector{String},
    ::Type{ConstantExcitation},
)
    # Extract generator and bus_ind
    gen = net["gen"]["$gen_ind"]

    # Find indexes of machine variables
    var_index = find_variable_index(var_list, pad_with_element_index("Efd", gen_ind))
    inds_out = [var_index]
    inds_du = []
    inds_u = [var_index]

    return inds_out, inds_du, inds_u
end


"""
    generate_ic!(net, gen_ind, ::Type{ConstantExcitation})

Calculates initial conditions of a constant excitation model for a synchronous generator.

# Arguments
- `net`: Power system data in network data dictionary format.
- `gen_ind`: Index of the generator in the network data dictionary.
- `::Type{ConstantExcitation}`: Type of constant excitation model.

# Note

The initial value of the excitation voltage, `Efd0`, is calculated during the initialisation of the SynchronousGeneratorModel that the model is connected to.
"""
function generate_ic!(net, gen_ind, ::Type{ConstantExcitation})
    return DataFrame(
        :names => pad_with_element_index("Efd", gen_ind),
        :values => [net["gen"]["$gen_ind"]["dynamic_model"]["parameters"]["Efd0"]],
    )
end

#######################################################################
# RECALCULATE STATE
#######################################################################
#######################################################################
function algebraic_equations!(F, vars, states, model::ConstantExcitation)
    # Extract parameters directly from the model
    Efd0 = model.Efd0

    # Extract variables from input vector 'u'
    Efd = vars[1]

    # ZIPModelLoad equations
    F[1] = -Efd + Efd0
end