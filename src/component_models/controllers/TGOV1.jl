"""
    TGOV1 <: GovernorModel

Type definition for the TGOV1 thermal governor model.

# Fields
- `T1`: Steam bowl time constant (s).
- `T2`: Numerator time constant of T2, T3 block (s).
- `T3`: Reheater time constant (s).
- `Rd`: Droop (p.u.).
- `P_set`: Power setpoint (p.u.).
- `ωs`: Synchronous speed (rad/s).
- `Vmin`: Minimum valve position.
- `Vmax`: Maximum valve position.
"""
struct TGOV1 <: GovernorModel
    T1
    T2
    T3
    Rd
    P_set
    ωs
    Vmin
    Vmax
end

variables(::Type{TGOV1}) = ["Pm", "Pv", "Tm"]
differential_variables(::Type{TGOV1}) = ["dPm", "dPv"]

"""
    update!(out, du, u, model::TGOV1, t)

Implements the differntial and algebraic equations for the sixth order synchronous generator model.

Model is based on [Governor TGOV1](https://www.powerworld.com/WebHelp/Content/TransientModels_HTML/Governor%20TGOV1%20and%20TGOV1D.htm).

# Variables

All per-unit quantities are expressed on the generator MVA base values.

### State Variables
- `Pm`: Turbine power output (p.u.).
- `Pv`: Valve position (p.u.).

### Algebraic Variables
- `Tm`: Mechanical torque (p.u.).

### External variables
- `ω` : Angular velocity of the generator (rad/s).

# Equations

``T_1 \\frac{dP_v}{dt} =  -P_v + \\frac{1}{R_d} (P_{set} - Δω)``

``T_3 \\frac{dP_m}{dt} = -P_m + P_v + T_2 \\frac{dP_v}{dt}``

``\\frac{dT_m}{dt} = -P_m + T_m ω``

``V_{min} ≤ P_v ≤ V_{max}``

where

``Δω = ω / ωs - 1``
"""
function update!(out, du, u, model::TGOV1, t)
    # Extract parameters directly from the model
    T1, T2, T3, Rd, P_set, ωs, Vmin, Vmax =
        model.T1, model.T2, model.T3, model.Rd, model.P_set, model.ωs, model.Vmin, model.Vmax

    # Extract variables from input vector 'u' and 'du'
    (Pm, Pv, Tm, ω) = u
    (dPm, dPv) = du

    # Calaculate speed deviation Δω
    Δω = ω / ωs - 1

    # Differential Equations
    reference_signal = (1 / Rd) * (P_set - Δω)
    out[1] = first_order_nonwindup(Pv, dPv, reference_signal, T1, Vmin, Vmax)
    out[2] = -T3 * dPm - Pm + Pv + T2 * dPv
    out[3] = -Pm + Tm * ω
end

function make_dynamic_model(net::Dict{String,Any}, gen_ind::Int64, ::Type{TGOV1})
    gov = net["gen"]["$gen_ind"]["dynamic_model"]["controllers"]["TGOV1"]
    gov_parameters = gov["parameters"]
    # Extract generator parameters
    T1 = gov_parameters["T1"]
    T2 = gov_parameters["T2"]
    T3 = gov_parameters["T3"]
    Rd = gov_parameters["Rd"]
    ωs = net["gen"]["$gen_ind"]["dynamic_model"]["parameters"]["ωs"]
    P_set = gov_parameters["P_set"]
    Vmin = gov_parameters["Vmin"]
    Vmax = gov_parameters["Vmax"]
    # Define dynamic model
    gov_model = TGOV1(T1, T2, T3, Rd, P_set, ωs, Vmin, Vmax)
    return gov_model
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    gen_ind::Int64,
    var_list::Vector{String},
    ::Type{TGOV1},
)
    # Extract generator and bus_ind
    gen = net["gen"]["$gen_ind"]

    # Extract variable names for governor model 
    governor_vars = [
        pad_with_element_index.(variables(TGOV1), gen_ind)
        pad_with_element_index("ω", gen_ind)
    ]

    # Find indexes of machine variables
    var_indexes = find_variable_indexes(var_list, governor_vars)
    inds_out = var_indexes[1:3]
    inds_du = var_indexes[1:2]
    inds_u = var_indexes

    return inds_out, inds_du, inds_u
end

"""
    generate_ic!(net, gen_ind, ::Type{TGOV1})

Calculates initial conditions for a TGOV1 governor model.

# Arguments
- `net`: Power system data in network data dictionary format.
- `gen_ind`: Index of the generator in the network data dictionary.
- `::Type{TGOV1}`: Type of the TGOV1 governor model.

# Equations

The initial value of the mechanical torque, `Tm0`, is calculated during the initialisation of the SynchronousGeneratorModel that the model is connected to.

All other variables are initialised to `Tm0`.

``Pm = Tm0``

``Pv = Tm0``

``Tm = Tm0``

Power setpoint is proportional to droop, and is calculated as 

``P_{set} = Tm0 * Rd``
"""
function generate_ic!(net, gen_ind, ::Type{TGOV1})
    # Extract gen and governor
    gen = net["gen"]["$gen_ind"]
    gov = gen["dynamic_model"]["controllers"]["TGOV1"]
    gov_parameters = gov["parameters"]

    # Extract relevant parameters values from gen dict
    Tm0 = gen["dynamic_model"]["parameters"]["Tm0"]
    Rd = gov_parameters["Rd"]

    # Note that in steady state, both Pv and Pm should equal Tm
    # Calculate power setpoint
    gov_parameters["P_set"] = Tm0 * Rd

    # Prepare dataframe for return
    gov_initial_state = DataFrame(
        :names => pad_with_element_index.(variables(TGOV1), gen_ind),
        :values => [Tm0, Tm0, Tm0],
    )

    return gov_initial_state
end

function add_default!(net::Dict, gen_ind, ::Type{TGOV1})
    # Extract gen from network model
    gen = net["gen"]["$gen_ind"]

    # Create governor dict and populate with default parameters
    gen["gov"] = Dict{String,Any}(
        "model_type" => TGOV1,
        "T1" => 0.5,
        "T2" => 2.1,
        "T3" => 7.0,
        "Rd" => 0.05,
    )
end

#######################################################################
# RECALCULATE STATE
#######################################################################
function algebraic_equations!(F, vars, states, model::TGOV1)
    # Extract algebraic variables
    Tm = vars[1]
    # Extract state variables
    (Pm, Pv, ω) = states[1:3]
    # Differential Equations
    F[1] = -Pm + Tm * ω

end

function calculate_state_derivatives!(du, u, model::TGOV1, inds_du, inds_u)
    # Extract parameters directly from the model
    T1, T2, T3, Rd, P_set, ωs =
        model.T1,
        model.T2,
        model.T3,
        model.Rd,
        model.P_set,
        model.ωs


    # Extract variables from post fault state
    (Pm, Pv, Tm, ω) = u[inds_u]

    # Calaculate speed deviation Δω
    Δω = ω / ωs - 1

    # Differential Equations
    dPv = (1 / T1) * (-Pv + (1 / Rd) * (P_set - Δω))
    dPm = (1 / T3) * (-Pm + Pv + T2 * dPv)

    du[inds_du] = [dPm, dPv]
end


