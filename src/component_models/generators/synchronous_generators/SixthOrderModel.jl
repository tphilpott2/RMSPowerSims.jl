"""
    SixthOrderModel <: SynchronousGeneratorModel

Type definition for the sixth order synchronous machine model.

# Fields
All fields specified to be in per unit values are expressed on the generator base values.
- `H`: Inertia constant (s)
- `Rs`: Stator resistance (p.u.)
- `Xl`: Stator Leakage reactance (p.u.)
- `Xd`: d-axis reactance (p.u.)
- `Xq`: q-axis reactance (p.u.)
- `Xd_d`: d-axis transient reactance (p.u.)
- `Xq_d`: q-axis transient reactance (p.u.)
- `Xd_dd`: d-axis subtransient reactance (p.u.)
- `Xq_dd`: q-axis subtransient reactance (p.u.)
- `Tdo_d`: d-axis open circuit time constant (s)
- `Tqo_d`: q-axis open circuit time constant (s)
- `Tdo_dd`: d-axis subtransient time constant (s)
- `Tqo_dd`: q-axis subtransient time constant (s)
- `ωs`: Synchronous speed (p.u.)
- `f_nom`: Nominal system frequency (Hz)
- `Vb_gen`: Generator base voltage (kV)
- `Vb_sys`: System base voltage (kV)
- `Sb_gen`: Generator base power (MVA)
- `Sb_sys`: System base power (MVA)
- `consider_ωr_variations`: Set to 1 if rotor speed variations should be considered, 0 if not.

Note: The time constants `Tdo_d`, `Tqo_d`, `Tdo_dd`, and `Tqo_dd` are the open loop time constants, not short circuit.
"""
struct SixthOrderModel <: SynchronousGeneratorModel
    H
    Rs
    Xl
    Xd
    Xq
    Xd_d
    Xq_d
    Xd_dd
    Xq_dd
    Tdo_d
    Tqo_d
    Tdo_dd
    Tqo_dd
    ωs
    f_nom
    Vb_gen
    Vb_sys
    Sb_gen
    Sb_sys
    consider_ωr_variations
end

variables(::Type{SixthOrderModel}) = ["Eq", "Ed", "ψ1d", "ψ2q", "δ", "ω", "Id", "Iq", "Pg", "Qg"]
differential_variables(::Type{SixthOrderModel}) = ["dEq", "dEd", "dψ1d", "dψ2q", "dδ", "dω"]

"""
    update!(out, du, u, model::SixthOrderModel, t)

Implements the differntial and algebraic equations for the sixth order synchronous generator model.

Model based on P. W. Sauer and M. A. Pai, "Power System Dynamics and Stability", Upper Saddle River, NJ: Prentice Hall, 1998.

# Variables

All quantities specified in per unit values are expressed on the generator base values unless stated otherwise.

### State Variables
- `Eq`: Scaled flux in field winding (p.u.)
- `Ed`: Scaled flux in 1q damper winding (p.u.)
- `ψ1d`: Flux in 1d damper winding (p.u.)
- `ψ2q`: Flux in 2q damper winding (p.u.)
- `δ`: Rotor angle (rad)
- `ω`: Rotor speed (p.u.)

### Algebraic Variables
- `Id`: d-axis current (p.u.)
- `Iq`: q-axis current (p.u.)
- `Pg`: Active power injection (p.u. using system base values)
- `Qg`: Reactive power injection (p.u. using system base values)

### External variables
- `ω_ref`: Rotor speed reference (p.u.)
- `V`: Terminal voltage (p.u. using system base values)
- `θ`: Terminal voltage angle (rad)
- `Efd`: Exciter voltage (p.u.)
- `Tm`: Mechanical torque (p.u.)

# Equations

### Effect of rotor speed variations

If `consider_ωr_variations` is set to 1, then

``ω_{var} = \\frac{ω}{ω_s}``

otherwise
    
``ω_{var} = 1``

### Conversions and dq-transform

``V_{gen} = V * \\frac{Vb_{sys}}{Vb_{gen}}``

``V = (V_d + j V_q) (\\cos(\\delta - \\frac{\\pi}{2}) + j \\sin(\\delta - \\frac{\\pi}{2}))``

### Rotor flux equations

``T'_{do} \\frac{dE_q}{dt} = - E_q - (X_d - X'_d) (I_d - (\\frac{X'_d - X''_d}{(X'_d - X_l)^2}) (\\psi_{1d} + (X'_d - X_l)  I_d - Eq)) + E_{fd} ``

``T'_{qo} \\frac{dE_d}{dt} = - E_d + (X_q - X'_q) (I_q - (\\frac{X'_q - X''_q}{(X'_q - X_l)^2} ) (\\psi_{2q} + (X'_q - X_l) I_q + E_d))``

``T''_{do} \\frac{d\\psi_{1d}}{dt} = - \\psi_{1d} + E_q - (X'_{d} - X_l) I_d``

``T''_{qo} \\frac{d\\psi_{2q}}{dt} = - \\psi_{2q} - E_d - (X'_{q} - X_l) I_q``

### Mechanical Equations

``\\frac{d\\delta}{dt}  = 2 \\pi f_{nom} (\\omega - \\omega_{ref})``

``(\\frac{2H}{\\omega_s} ) \\frac{d\\omega}{dt} = T_m - Te``

where

``Te = ( V_d I_d + V_q I_q + R_s ( I_d^2 + I_q^2 ) ) / \\omega_{var} ``

### Stator Equations

``0  = V \\sin(\\delta - \\theta) + R_s I_d + \\omega_{var} ( -X''_{q} I_q - (\\frac{X''_{q} - X_l}{X'_{q} - X_l}) E_d + (\\frac{X'_{q} - X''_{q}}{X'_{q} - X_l}) \\psi_{2q} )``

``0  = V \\cos(\\delta - \\theta) + R_s I_q + \\omega_{var} ( X''_{d} I_d - (\\frac{X''_{d} - X_l}{X'_{d} - X_l}) E_q - (\\frac{X'_{d} - X''_{d}}{X'_{d} - X_l}) \\psi_{1d} )``

### Power injection to bus

``0 = -Pg + (I_d V \\sin(\\delta - \\theta) + I_q V \\cos(\\delta - \\theta)) (\\frac{S_{b_{gen}}}{S_{b_{sys}}})``

``0 = -Qg + (I_d V \\cos(\\delta - \\theta) - I_q V \\sin(\\delta - \\theta)) (\\frac{S_{b_{gen}}}{S_{b_{sys}}})``

"""
function update!(
    out,
    du,
    u,
    model::SixthOrderModel,
    t,
)
    # Extract parameters directly from the model
    H, Rs, Xl, Xd, Xq, Xd_d, Xq_d, Xd_dd, Xq_dd, Tdo_d, Tqo_d, Tdo_dd, Tqo_dd, ωs, f_nom, Vb_gen, Vb_sys, Sb_gen, Sb_sys, consider_ωr_variations =
        model.H,
        model.Rs,
        model.Xl,
        model.Xd,
        model.Xq,
        model.Xd_d,
        model.Xq_d,
        model.Xd_dd,
        model.Xq_dd,
        model.Tdo_d,
        model.Tqo_d,
        model.Tdo_dd,
        model.Tqo_dd,
        model.ωs,
        model.f_nom,
        model.Vb_gen,
        model.Vb_sys,
        model.Sb_gen,
        model.Sb_sys,
        model.consider_ωr_variations

    # Extract variables from input vector 'u' and 'du'
    (Eq, Ed, ψ1d, ψ2q, δ, ω, Id, Iq, Pg, Qg, ω_ref, V, θ, Efd, Tm) = u
    (dEq, dEd, dψ1d, dψ2q, dδ, dω) = du

    # rotor speed variation term
    ω_var = consider_ωr_variations ? ω / ωs : 1
    # ω_var = 1 + (ω / ωs - 1) * consider_ωr_variations # non conditional formulation

    # calculate electrical torque
    V_gen = V * Vb_sys / Vb_gen # convert to generator base voltage
    (Vd, Vq) = dq_transform(ptc(V_gen, θ), δ)
    Te = (Vd * Id + Vq * Iq + Rs * (Id^2 + Iq^2)) / ω_var

    # Rotor flux equations
    out[1] =
        -dEq * Tdo_d - Eq -
        (Xd - Xd_d) *
        (Id - ((Xd_d - Xd_dd) / (Xd_d - Xl)^2) * (ψ1d + (Xd_d - Xl) * Id - Eq)) + Efd
    out[2] =
        -dEd * Tqo_d - Ed +
        (Xq - Xq_d) *
        (Iq - ((Xq_d - Xq_dd) / (Xq_d - Xl)^2) * (ψ2q + (Xq_d - Xl) * Iq + Ed))
    out[3] = -dψ1d * Tdo_dd - ψ1d + Eq - (Xd_d - Xl) * Id
    out[4] = -dψ2q * Tqo_dd - ψ2q - Ed - (Xq_d - Xl) * Iq
    # Mechanical equatiuons
    out[5] = -dδ + (2 * pi * f_nom) * (ω - ω_ref)
    out[6] = -dω * (2 * H / ωs) + Tm - Te
    # Stator equations
    out[7] =
        V_gen * sin(δ - θ) +
        Rs * Id +
        ω_var * (
            -Xq_dd * Iq - ((Xq_dd - Xl) / (Xq_d - Xl)) * Ed +
            ((Xq_d - Xq_dd) / (Xq_d - Xl)) * ψ2q
        )
    out[8] =
        V_gen * cos(δ - θ) +
        Rs * Iq +
        ω_var * (
            Xd_dd * Id - ((Xd_dd - Xl) / (Xd_d - Xl)) * Eq -
            ((Xd_d - Xd_dd) / (Xd_d - Xl)) * ψ1d
        )
    # Power injection to bus (converted to system base power)
    out[9] = -Pg + (Id * V_gen * sin(δ - θ) + Iq * V_gen * cos(δ - θ)) * (Sb_gen / Sb_sys)
    out[10] = -Qg + (Id * V_gen * cos(δ - θ) - Iq * V_gen * sin(δ - θ)) * (Sb_gen / Sb_sys)
end

function make_dynamic_model(net::Dict{String,Any}, gen_ind::Int64, ::Type{SixthOrderModel})
    gen = net["gen"]["$gen_ind"]
    # Extract generator parameters
    H = gen["dynamic_model"]["parameters"]["H"]
    Rs = gen["dynamic_model"]["parameters"]["Rs"]
    Xl = gen["dynamic_model"]["parameters"]["Xl"]
    Xd = gen["dynamic_model"]["parameters"]["Xd"]
    Xq = gen["dynamic_model"]["parameters"]["Xq"]
    Xd_d = gen["dynamic_model"]["parameters"]["Xd_d"]
    Xq_d = gen["dynamic_model"]["parameters"]["Xq_d"]
    Xd_dd = gen["dynamic_model"]["parameters"]["Xd_dd"]
    Xq_dd = gen["dynamic_model"]["parameters"]["Xq_dd"]
    Tdo_d = gen["dynamic_model"]["parameters"]["Td_d"]
    Tqo_d = gen["dynamic_model"]["parameters"]["Tq_d"]
    Tdo_dd = gen["dynamic_model"]["parameters"]["Td_dd"]
    Tqo_dd = gen["dynamic_model"]["parameters"]["Tq_dd"]
    ωs = gen["dynamic_model"]["parameters"]["ωs"]
    f_nom = net["dynamic_model_parameters"]["f_nom"]
    Vb_gen = gen["vbase"]
    Vb_sys = net["bus"]["$(gen["gen_bus"])"]["base_kv"]
    Sb_gen = gen["mbase"]
    Sb_sys = net["baseMVA"]
    consider_ωr_variations = gen["dynamic_model"]["parameters"]["consider_ωr_variations"]

    # Create generator model
    gen_model = SixthOrderModel(
        H,
        Rs,
        Xl,
        Xd,
        Xq,
        Xd_d,
        Xq_d,
        Xd_dd,
        Xq_dd,
        Tdo_d,
        Tqo_d,
        Tdo_dd,
        Tqo_dd,
        ωs,
        f_nom,
        Vb_gen,
        Vb_sys,
        Sb_gen,
        Sb_sys,
        consider_ωr_variations
    )
    return gen_model
end

function make_pointers_to_simulation_variables(
    net::Dict{String,Any},
    gen_ind::Int64,
    var_list::Vector{String},
    ::Type{SixthOrderModel},
)
    # Extract generator and bus_ind
    gen = net["gen"]["$gen_ind"]
    bus_ind = gen["gen_bus"]
    # Extract variable names for sixth order synchronous machine model 

    sixth_order_vars = [
        pad_with_element_index.(variables(SixthOrderModel), gen_ind)
        get_reference_gen_index(net)
        pad_with_element_index.(["V", "θ"], bus_ind)
        pad_with_element_index.(["Efd", "Tm"], gen_ind)
    ]

    # Find indexes of machine variables
    var_indexes = find_variable_indexes(var_list, sixth_order_vars)
    inds_out = var_indexes[1:10]
    inds_du = var_indexes[1:6]
    inds_u = var_indexes

    return inds_out, inds_du, inds_u
end

"""
    generate_ic!(net, gen_ind, ::Type{SixthOrderModel})

Calculates initial conditions for the sixth order synchronous machine model.

# Equations

### Load Flow Solution and Per-Unit Conversion

The parameters `P`, `Q`, `V`, and `θ` are extracted from the load flow solution, where
    
- `P` is the active power output of the generator (p.u. using system base values),
- `Q` is the reactive power output of the generator (p.u. using system base values),
- `V` is the terminal voltage of the generator (p.u. using system base values),
- `θ` is the terminal voltage angle of the generator (rad),

Generator current injection is then calculated as

``I_{sys} = \\frac{P - jQ}{V \\angle -θ}``

where

- `I_{sys}` is the current injection (p.u. using system base values),

Converting to generator base values

``I_{gen} = I_{sys} \\frac{Sb_{sys}}{Sb_{gen}} \\frac{Vb_{gen}}{Vb_sys}}``

``V_{gen} = V \\frac{Vb_{sys}}{Vb_{gen}}``

where 

- `I_{gen}` is the current injection (p.u. using generator base values),

- `V_{gen}` is the terminal voltage of the generator (p.u. using generator base values),

### Generator Equations

The system of nonlinear generator equations shown below is solved using the NLSolve.jl nonlinear equation solver. The variables to be solved for are `Eq`, `Ed`, `ψ1d`, `ψ2q`, `δ`, `ω`, `Id`, `Iq`, `Pg`, `Qg`, `Efd`, and `Tm`. The equations are determined by setting the derivatives of the state variables to zero, and the speed, `ω`, to 1 p.u.
"""
function generate_ic!(net, gen_ind, ::Type{SixthOrderModel})
    # Extract gen and gen_bus
    gen = net["gen"]["$gen_ind"]
    gen_bus = net["bus"]["$(gen["gen_bus"])"]

    # Extract ldf solution
    V = gen_bus["vm"]
    θ = gen_bus["va"]
    P = gen["pg"]
    Q = gen["qg"]

    # Extract relevant parameters values from gen dict
    Rs = gen["dynamic_model"]["parameters"]["Rs"]
    Xl = gen["dynamic_model"]["parameters"]["Xl"]
    Xd = gen["dynamic_model"]["parameters"]["Xd"]
    Xq = gen["dynamic_model"]["parameters"]["Xq"]
    Xd_d = gen["dynamic_model"]["parameters"]["Xd_d"]
    Xq_d = gen["dynamic_model"]["parameters"]["Xq_d"]
    Xd_dd = gen["dynamic_model"]["parameters"]["Xd_dd"]
    Xq_dd = gen["dynamic_model"]["parameters"]["Xq_dd"]
    Sb_gen = gen["mbase"]
    Sb_sys = net["baseMVA"]
    Vb_gen = gen["vbase"]
    Vb_sys = gen_bus["base_kv"]

    # Calculate current injection and convert to generator base
    I_sys = (P - 1im * Q) / ptc(V, -θ)

    # Convert to generator base power and voltage
    I_gen = I_sys * (Sb_sys / Vb_sys) / (Sb_gen / Vb_gen)
    V_gen = V * Vb_sys / Vb_gen


    # Define system of equations
    function sixth_order_steady_state_equations!(F, vars)
        (Eq, Ed, ψ1d, ψ2q, δ, ω, Id, Iq, Pg, Qg, Efd, Tm) = vars

        # Rotor flux equations
        F[1] =
            -Eq -
            (Xd - Xd_d) *
            (Id - ((Xd_d - Xd_dd) / ((Xd_d - Xl)^2)) * (ψ1d + (Xd_d - Xl) * Id - Eq)) + Efd
        F[2] =
            -Ed +
            (Xq - Xq_d) *
            (Iq - ((Xq_d - Xq_dd) / ((Xq_d - Xl)^2)) * (ψ2q + (Xq_d - Xl) * Iq + Ed))
        F[3] = -ψ1d + Eq - (Xd_d - Xl) * Id
        F[4] = -ψ2q - Ed - (Xq_d - Xl) * Iq
        # Mechanical equations
        (Vd, Vq) = dq_transform(ptc(V_gen, θ), δ)
        Te = (Vd * Id + Vq * Iq + Rs * (Id^2 + Iq^2))
        F[5] = Tm - Te
        F[6] = -ω + 1

        # Stator algebraic equations
        F[7] =
            V_gen * sin(δ - θ) + Rs * Id - Xq_dd * Iq - ((Xq_dd - Xl) / (Xq_d - Xl)) * Ed +
            ((Xq_d - Xq_dd) / (Xq_d - Xl)) * ψ2q
        F[8] =
            V_gen * cos(δ - θ) + Rs * Iq + Xd_dd * Id - ((Xd_dd - Xl) / (Xd_d - Xl)) * Eq -
            ((Xd_d - Xd_dd) / (Xd_d - Xl)) * ψ1d

        # dq voltages and currents
        Idq = dq_transform(I_gen, δ)
        F[9] = -Id + Idq[1]
        F[10] = -Iq + Idq[2]

        # power injection (converted to system base)
        F[11] = -Pg + (Id * V_gen * sin(δ - θ) + Iq * V_gen * cos(δ - θ)) * (Sb_gen / Sb_sys)
        F[12] = -Qg + (Id * V_gen * cos(δ - θ) - Iq * V_gen * sin(δ - θ)) * (Sb_gen / Sb_sys)
    end
    # Initial guess for the variables
    initial_guess = zeros(Float64, 12)
    # Solve the system
    solution = nlsolve(sixth_order_steady_state_equations!, initial_guess)

    # Check for convergence and process results
    if solution.f_converged
        # Pair names with state variables before returning
        gen_initial_state = DataFrame(
            :names => pad_with_element_index.(variables(SixthOrderModel), gen_ind),
            :values => solution.zero[1:10],
        )

        # Update gen dict to include initial Efd and Tm
        gen["dynamic_model"]["parameters"]["Efd0"] = solution.zero[11]
        gen["dynamic_model"]["parameters"]["Tm0"] = solution.zero[12]

        return gen_initial_state
    else
        println("initial conditions didn't converge for gen $(gen["index"])")
    end
end

#######################################################################
# RECALCULATE STATE
#######################################################################

function algebraic_equations!(F, vars, states, model::SixthOrderModel)
    # Extract parameters directly from the model
    Rs, Xl, Xd_d, Xq_d, Xd_dd, Xq_dd, ωs, Vb_gen, Vb_sys, Sb_gen, Sb_sys, consider_ωr_variations =
        model.Rs,
        model.Xl,
        model.Xd_d,
        model.Xq_d,
        model.Xd_dd,
        model.Xq_dd,
        model.ωs,
        model.Vb_gen,
        model.Vb_sys,
        model.Sb_gen,
        model.Sb_sys,
        model.consider_ωr_variations

    # Extract variables from input vector 'u' and 'du'
    (Id, Iq, Pg, Qg, V, θ) = vars[1:6]
    (Eq, Ed, ψ1d, ψ2q, δ, ω) = states[1:6]

    # convert to generator base voltage
    V_gen = V * Vb_sys / Vb_gen

    # rotor speed variation term
    ω_var = consider_ωr_variations ? ω / ωs : 1
    # ω_var = 1 + (ω / ωs - 1) * consider_ωr_variations # non conditional formulation

    # Stator equations
    F[1] =
        V_gen * sin(δ - θ) +
        Rs * Id +
        ω_var * (
            -Xq_dd * Iq - ((Xq_dd - Xl) / (Xq_d - Xl)) * Ed +
            ((Xq_d - Xq_dd) / (Xq_d - Xl)) * ψ2q
        )
    F[2] =
        V_gen * cos(δ - θ) +
        Rs * Iq +
        ω_var * (
            Xd_dd * Id - ((Xd_dd - Xl) / (Xd_d - Xl)) * Eq -
            ((Xd_d - Xd_dd) / (Xd_d - Xl)) * ψ1d
        )
    # Power injection to bus (converted to system base power)
    F[3] = -Pg + (Id * V_gen * sin(δ - θ) + Iq * V_gen * cos(δ - θ)) * (Sb_gen / Sb_sys)
    F[4] = -Qg + (Id * V_gen * cos(δ - θ) - Iq * V_gen * sin(δ - θ)) * (Sb_gen / Sb_sys)
end

function calculate_state_derivatives!(du, u, model::SixthOrderModel, inds_du, inds_u)
    # Extract parameters directly from the model
    H, Rs, Xl, Xd, Xq, Xd_d, Xq_d, Xd_dd, Xq_dd, Tdo_d, Tqo_d, Tdo_dd, Tqo_dd, ωs, f_nom, Vb_gen, Vb_sys, consider_ωr_variations =
        model.H,
        model.Rs,
        model.Xl,
        model.Xd,
        model.Xq,
        model.Xd_d,
        model.Xq_d,
        model.Xd_dd,
        model.Xq_dd,
        model.Tdo_d,
        model.Tqo_d,
        model.Tdo_dd,
        model.Tqo_dd,
        model.ωs,
        model.f_nom,
        model.Vb_gen,
        model.Vb_sys,
        model.consider_ωr_variations



    # Extract variables from post fault state
    (Eq, Ed, ψ1d, ψ2q, δ, ω, Id, Iq, Pg, Qg, ω_ref, V, θ, Efd, Tm) = u[inds_u]

    # rotor speed variation term
    ω_var = consider_ωr_variations ? ω / ωs : 1
    # ω_var = 1 + (ω / ωs - 1) * consider_ωr_variations # non conditional formulation

    # calculate electrical torque
    V_gen = V * Vb_sys / Vb_gen # convert to generator base voltage
    (Vd, Vq) = dq_transform(ptc(V_gen, θ), δ)
    Te = (Vd * Id + Vq * Iq + Rs * (Id^2 + Iq^2)) / ω_var

    # Rotor flux equations
    dEq = (1 / Tdo_d) * (-Eq -
                         (Xd - Xd_d) *
                         (Id - ((Xd_d - Xd_dd) / (Xd_d - Xl)^2) * (ψ1d + (Xd_d - Xl) * Id - Eq)) + Efd)

    dEd = (1 / Tqo_d) * (-Ed +
                         (Xq - Xq_d) *
                         (Iq - ((Xq_d - Xq_dd) / (Xq_d - Xl)^2) * (ψ2q + (Xq_d - Xl) * Iq + Ed)))
    dψ1d = (1 / Tdo_dd) * (-ψ1d + Eq - (Xd_d - Xl) * Id)
    dψ2q = (1 / Tqo_dd) * (-ψ2q - Ed - (Xq_d - Xl) * Iq)
    # Mechanical equatiuons
    dδ = (2 * pi * f_nom) * (ω - ω_ref)
    dω = ωs * (Tm - Te) / (2 * H)

    du[inds_du] = [dEq, dEd, dψ1d, dψ2q, dδ, dω]
end