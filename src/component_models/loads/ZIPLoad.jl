"""
    ZIPLoad <: LoadModel

Type definition for the ZIP load model.

# Fields
- `Pd0`: Active power demand at nominal voltage (p.u.).
- `Qd0`: Reactive power demand at nominal voltage (p.u.).
- `V_nom`: Nominal voltage (p.u.). Note: Nominal voltage is set to load flow solution.
- `Kpz`: Active power constant impedance coefficient.
- `Kpi`: Active power constant current coefficient.
- `Kpc`: Active power constant power coefficient.
- `Kqz`: Reactive power constant impedance coefficient.
- `Kqi`: Reactive power constant current coefficient.
- `Kqc`: Reactive power constant power coefficient.

"""
mutable struct ZIPLoad <: LoadModel
    Pd0
    Qd0
    V_nom
    Kpz
    Kpi
    Kpc
    Kqz
    Kqi
    Kqc
end

variables(::Type{ZIPLoad}) = ["Pd", "Qd"]
differential_variables(::Type{ZIPLoad}) = []

"""
    update!(out, du, u, model::ZIPLoad, t)

Implements the equations for the ZIPLoad model.

# Variables

### Algebraic Variables

- `Pd`: Active power demand (p.u.).
- `Qd`: Reactive power demand (p.u.).

### External variables

- `V`: Voltage at the load bus (p.u.).

# Equations

``P_d = P_{d0} (K_{pz} ΔV^2 + K_{pi} ΔV + K_{pc})``

``Q_d = Q_{d0} (K_{qz} ΔV^2 + K_{qi} ΔV + K_{qc})``

where

``ΔV = V / V_{nom}``
"""
function update!(out, du, u, model::ZIPLoad, t)
    # Extract parameters directly from the model
    Pd0, Qd0, V_nom, Kpz, Kpi, Kpc, Kqz, Kqi, Kqc = model.Pd0,
    model.Qd0,
    model.V_nom,
    model.Kpz,
    model.Kpi,
    model.Kpc,
    model.Kqz,
    model.Kqi,
    model.Kqc

    # Extract variables from input vector 'u'
    (Pd, Qd, V) = u

    # Calculate voltage difference from nominal value
    ΔV = V / V_nom

    # ZIPModelLoad equations
    out[1] = -Pd + Pd0 * (Kpz * ΔV^2 + Kpi * ΔV + Kpc)
    out[2] = -Qd + Qd0 * (Kqz * ΔV^2 + Kqi * ΔV + Kqc)
end

function make_dynamic_model(net::Dict{String,Any}, load_ind::Int64, ::Type{ZIPLoad})
    # Extract bus from network
    load = net["load"]["$load_ind"]


    # Extract parameters
    Pd0 = load["pd"]
    Qd0 = load["qd"]
    Kpz = load["dynamic_model"]["parameters"]["Kpz"]
    Kpi = load["dynamic_model"]["parameters"]["Kpi"]
    Kqz = load["dynamic_model"]["parameters"]["Kqz"]
    Kqi = load["dynamic_model"]["parameters"]["Kqi"]
    Kpc = 1 - Kpz - Kpi
    Kqc = 1 - Kqz - Kqi
    V0 = net["bus"]["$(load["load_bus"])"]["vm"]

    # Define ZipLoad equations
    ZIPLoad_model = ZIPLoad(Pd0, Qd0, V0, Kpz, Kpi, Kpc, Kqz, Kqi, Kqc)

    return ZIPLoad_model
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    load_ind::Int64,
    var_list::Vector{String},
    ::Type{ZIPLoad},
)
    # Extract bus from network
    load = net["load"]["$load_ind"]
    # Get indexes of outputs
    inds_u = [
        find_variable_index(var_list, "Pd_$load_ind")
        find_variable_index(var_list, "Qd_$load_ind")
        find_variable_index(var_list, "V_$(load["load_bus"])")
    ]
    inds_du = []
    inds_out = inds_u[1:2]
    return inds_out, inds_du, inds_u
end

function algebraic_equations!(F, vars, states, model::ZIPLoad)
    # Extract parameters directly from the model
    Pd0, Qd0, V_nom, Kpz, Kpi, Kpc, Kqz, Kqi, Kqc = model.Pd0,
    model.Qd0,
    model.V_nom,
    model.Kpz,
    model.Kpi,
    model.Kpc,
    model.Kqz,
    model.Kqi,
    model.Kqc

    # Extract variables from input vector 'u'
    (Pd, Qd, V) = vars

    # Calculate voltage difference from nominal value
    ΔV = V / V_nom

    # ZIPModelLoad equations
    F[1] = -Pd + Pd0 * (Kpz * ΔV^2 + Kpi * ΔV + Kpc)
    F[2] = -Qd + Qd0 * (Kqz * ΔV^2 + Kqi * ΔV + Kqc)
end

"""
    generate_ic!(net, gen_ind, ::Type{ZIPLoad})

Calculates initial conditions for the ZIPLoad model.

Initial values of `Pd` and `Qd` are extracted directly from the load flow solution.
"""
function generate_ic!(net, load_ind, ::Type{ZIPLoad})
    return DataFrame(
        :names => pad_with_element_index.(variables(ZIPLoad), load_ind),
        :values => [
            net["load"]["$load_ind"]["pd"],
            net["load"]["$load_ind"]["qd"],
        ],
    )
end