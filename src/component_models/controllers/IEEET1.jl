"""
    IEEET1 <: AVRModel

Type definition for IEEET1 AVR model.

# Fields
- `Te`: Exciter time constant (s)
- `Ta`: Amplifier time constant (s)
- `Tf`: Filter time constant (s)
- `Tr`: Rate feedback time constant (s)
- `Ke`: Exciter gain (p.u.)
- `Ka`: Amplifier gain (p.u.)
- `Kf`: Filter gain (p.u.)
- `Vref`: Reference voltage (p.u.)
- `Se`::Function: Saturation function
- `Vrmin`: Minimum regulator voltage (p.u.)
- `Vrmax`: Maximum regulator voltage (p.u.)
- `Vb_gen`: Generator base voltage (kV)
- `Vb_sys`: System base voltage (kV)

"""
struct IEEET1 <: AVRModel
    Te
    Ta
    Tf
    Tr
    Ke
    Ka
    Kf
    Vref
    Se::Function
    Vrmin
    Vrmax
    Vb_gen
    Vb_sys
end

# info functions
variables(::Type{IEEET1}) = ["Efd", "Vt", "Vr", "Vf"]
differential_variables(::Type{IEEET1}) = ["dEfd", "dVt", "dVr", "dVf"]


#######################################################################
# UPDATE FUNCTIONS
#######################################################################
"""
    update!(out, du, u, model::IEEET1, t)

Implements the differntial equations for the IEEET1 AVR model.

Model is based on [Exciter IEEET1](https://www.powerworld.com/WebHelp/Content/TransientModels_HTML/Exciter%20IEEET1.htm).

# Variables

### State Variables
- `Efd`: Exciter voltage (p.u.)
- `Vt`: Measured Terminal voltage (p.u.)
- `Vr`: Regulator voltage (p.u.)
- `Vf`: Filter voltage (p.u.)

### External Variables
- `V`: Bus voltage (p.u.)

# Equations
``T_e\\frac{dEfd}{dt} = -K_e E_{fd} - S_e(E_{fd}) + V_r``
    
``T_a\\frac{dVt}{dt} = V_{gen} - V_t``

``T_r\\frac{dVr}{dt} = -V_r + K_a (V_{ref} - V_t - V_f)``

``T_f\\frac{dVf}{dt} = -V_f + K_f \\frac{dE_{fd}}{dt}``

``V_{rmin} <= Vr <= V_{rmax}``
"""
function update!(out, du, u, model::IEEET1, t)
    # Extract parameters directly from the model
    Te, Ta, Tf, Tr, Ke, Ka, Kf, Vref, Se, Vrmin, Vrmax, Vb_gen, Vb_sys = model.Te,
    model.Ta,
    model.Tf,
    model.Tr,
    model.Ke,
    model.Ka,
    model.Kf,
    model.Vref,
    model.Se,
    model.Vrmin,
    model.Vrmax,
    model.Vb_gen,
    model.Vb_sys

    # Extract variables from input vector 'u' and 'du'
    (Efd, Vt, Vr, Vf, V) = u
    (dEfd, dVt, dVr, dVf) = du

    # Convert bus voltage to generator base
    V_gen = V * Vb_sys / Vb_gen

    # Differential Equations
    out[1] = -dEfd * Te - Ke * Efd - Se(Efd) + Vr
    out[2] = -dVt * Tr + V_gen - Vt
    Vr_input = Ka * (Vref - Vt - Vf)
    out[3] = first_order_nonwindup(Vr, dVr, Vr_input, Ta, Vrmin, Vrmax)
    # out[3] = -dVr * Ta - Vr + Ka * (Vref - Vt - Vf)
    out[4] = -dVf * Tf - Vf + dEfd * Kf
end

#######################################################################
# GENERATE SYSTEM EQUATIONS
#######################################################################

function quadratic_saturation(x, E1, E2, Se1, Se2)
    # saturation function used by powerfactory
    sq = sqrt((E1 * Se1) / (E2 * Se2))
    Asq = (E1 - E2 * sq) / (1 - sq)
    Bsq = (E2 * Se2) / ((E2 - Asq)^2)

    Se(x) = x > Asq ? Bsq * (x - Asq)^2 : 0.0
    # Se(x) = Bsq * (x - Asq)^2
    # Se(x) = 0 * x
    return Se(x)
end

function exponential_saturation(x, Ax::Float64, Bx::Float64)
    Se(x) = Ax * exp(1)^(Bx * x)
    return Se
end


function make_dynamic_model(net::Dict{String,Any}, gen_ind::Int64, ::Type{IEEET1})
    # Extract IEEET1 
    avr = net["gen"]["$gen_ind"]["dynamic_model"]["controllers"]["IEEET1"]
    avr_parameters = avr["parameters"]

    # Extract parameters from avr dict
    Te = avr_parameters["Te"]
    Ta = avr_parameters["Ta"]
    Tf = avr_parameters["Tf"]
    Tr = avr_parameters["Tr"]
    Ke = avr_parameters["Ke"]
    Ka = avr_parameters["Ka"]
    Kf = avr_parameters["Kf"]
    Vref = avr_parameters["Vref"]
    Vrmin = avr_parameters["Vrmin"]
    Vrmax = avr_parameters["Vrmax"]
    Vb_gen = net["gen"]["$gen_ind"]["vbase"]
    Vb_sys = net["bus"]["$(net["gen"]["$gen_ind"]["gen_bus"] )"]["base_kv"]

    # Define saturation function
    Se(x) = quadratic_saturation(x, avr_parameters["E1"], avr_parameters["E2"], avr_parameters["Se1"], avr_parameters["Se2"])
    # Define dynamic model
    avr_model = IEEET1(Te, Ta, Tf, Tr, Ke, Ka, Kf, Vref, Se, Vrmin, Vrmax, Vb_gen, Vb_sys)
    return avr_model
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    gen_ind::Int64,
    var_list::Vector{String},
    ::Type{IEEET1},
)
    # Extract generator and bus_ind
    gen = net["gen"]["$gen_ind"]

    # Extract variable names for governor model 
    governor_vars = [
        pad_with_element_index.(variables(IEEET1), gen_ind)
        pad_with_element_index("V", gen["gen_bus"])
    ]

    # Find indexes of machine variables
    var_indexes = find_variable_indexes(var_list, governor_vars)
    inds_out = var_indexes[1:4]
    inds_du = var_indexes[1:4]
    inds_u = var_indexes

    return inds_out, inds_du, inds_u
end

"""
    generate_ic!(net, gen_ind, ::Type{IEEET1})

Calculates the initial conditions for the IEEET1 AVR model.

# Arguments
- `net::Dict{String,Any}`: Power system data in network data dictionary format.
- `gen_ind`: Index of the generator in the network data dictionary.
- `::Type{IEEET1}`: Type of the IEEET1 AVR model.

# Equations
Bus voltage, `V`, is taken from the load flow solution and converted to generator base voltage, `V_gen`, as

``V_{gen} = V * V_{base} / V_{gen}``

The initial value of the excitation voltage, `Efd0`, is calculated during the initialisation of the SynchronousGeneratorModel that the AVR is connected to.

The initial values of the remaining state variables are calculated as follows

``V_r = K_e E_{fd} + S_e(E_{fd})``

``V_t = V_{gen}``

``V_f = 0``

The reference voltage, `V_{ref}`, is calculated as

``V_{ref} = V_r / K_a + V_t``

"""
function generate_ic!(net, gen_ind, ::Type{IEEET1})
    # Extract generator, bus and AVR 
    gen = net["gen"]["$gen_ind"]
    gen_bus = net["bus"]["$(gen["gen_bus"])"]
    avr = gen["dynamic_model"]["controllers"]["IEEET1"]
    avr_parameters = avr["parameters"]

    # Extract parameters from avr dict
    Ke = avr_parameters["Ke"]
    Ka = avr_parameters["Ka"]
    Efd = gen["dynamic_model"]["parameters"]["Efd0"]

    # Define saturation function
    Se(x) = quadratic_saturation(x, avr_parameters["E1"], avr_parameters["E2"], avr_parameters["Se1"], avr_parameters["Se2"])

    # Calculate initial conditions
    V = gen_bus["vm"]
    V_gen = V * gen_bus["base_kv"] / gen["vbase"] # convert to generator vase voltage
    Vr = Ke * (Efd) + Se(Efd)
    Vt = V_gen
    Vf = 0

    # Calculate V_ref
    avr_parameters["Vref"] = Vr / Ka + Vt

    # Prepare dataframe for return
    avr_initial_state = DataFrame(
        :names => pad_with_element_index.(variables(IEEET1), gen_ind),
        :values => [Efd, Vt, Vr, Vf],
    )

    return avr_initial_state
end

function add_default!(net::Dict, gen_ind, ::Type{IEEET1})
    # Extract gen from network model
    gen = net["gen"]["$gen_ind"]

    # Create governor dict and populate with default parameters
    gen["avr"] = Dict{String,Any}(
        "model_type" => IEEET1,
        "Te" => 0.2,
        "Ta" => 0.03,
        "Tf" => 1.5,
        "Tr" => 0.02,
        "Ke" => 1.0,
        "Ka" => 200,
        "Kf" => 0.05,
        "E1" => 3.9,
        "E2" => 5.2,
        "Se1" => 0.1,
        "Se2" => 0.5,
        "Ax" => 0.013,
        "Bx" => 1.3,
    )

end

#######################################################################
# RECALCULATE STATE

function calculate_state_derivatives!(du, u, model::IEEET1, inds_du, inds_u)
    # Extract parameters directly from the model
    Te, Ta, Tf, Tr, Ke, Ka, Kf, Vref, Se, Vrmin, Vrmax, Vb_gen, Vb_sys =
        model.Te,
        model.Ta,
        model.Tf,
        model.Tr,
        model.Ke,
        model.Ka,
        model.Kf,
        model.Vref,
        model.Se,
        model.Vrmin,
        model.Vrmax,
        model.Vb_gen,
        model.Vb_sys

    # Extract variables from post fault state
    (Efd, Vt, Vr, Vf, V) = u[inds_u]

    # Convert bus voltage to generator base
    V_gen = V * Vb_sys / Vb_gen

    # Differential Equations
    dEfd = (1 / Te) * (-Ke * Efd - Se(Efd) + Vr)
    dVt = (1 / Tr) * (V_gen - Vt)
    dVr = (1 / Ta) * (-Vr + Ka * (Vref - Vt - Vf))
    dVf = (1 / Tf) * (-Vf + dEfd * Kf)
    du[inds_du] = [dEfd, dVt, dVr, dVf]
end
