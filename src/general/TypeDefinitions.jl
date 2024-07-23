###########################################################################
# Component model supertypes
###########################################################################
abstract type ComponentModel end

# Generator model type definitions
abstract type GeneratorModel <: ComponentModel end
abstract type SynchronousGeneratorModel <: GeneratorModel end

# Controller model type definitions
abstract type ControllerModel <: ComponentModel end
abstract type AVRModel <: ControllerModel end
abstract type GovernorModel <: ControllerModel end

# Load model type definitions
abstract type LoadModel <: ComponentModel end

###########################################################################
# Disturbance
###########################################################################
abstract type Disturbance end

###########################################################################
# Simulation data structures
###########################################################################
"""
    ComponentModelData
    
A struct containing the component model and the indices of the variables that appear in its equations.

# Fields
- `source_ind::Int64`: The index of the component in the network data dictionary (either a generator, load, or bus).
- `model::ComponentModel`: The component model.
- `inds_out::Vector{Int64}`: The indices of the equations in the output (residuals) vector.
- `inds_du::Vector{Int64}`: The indices of the state derivatives in the du vector.
- `inds_u::Vector{Int64}`: The indices of the state variables in the u vector.
"""
struct ComponentModelData
    source_ind::Int64
    model::ComponentModel
    inds_out::Vector{Int64}
    inds_du::Vector{Int64}
    inds_u::Vector{Int64}
end

"""
    PowerSystemModel

A struct containing a list of the component models, and a list of the simulation variables.

# Fields
- `component_list::Vector{ComponentModelData}`: A list of the component models and the indices of the variables that appear in their equations.
- `variables::Vector{String}`: A vector containing the names of the state/algebraic variables.
- `differential_vars::Vector{Bool}`: A boolean vector indicating whether each variable is a state variable (true) or an algebraic variable (false).
- `auxiliary_data`: Any additional data that needs to be passed to the solver.
"""
mutable struct PowerSystemModel
    component_list::Vector{ComponentModelData}
    variables::Vector{String}
    differential_vars::Vector{Bool}
    auxiliary_data
end

"""
    PowerSystemSimulation

A struct containing the data that will be passed to the differential equation solver.
    
# Fields
- `power_system_model::PowerSystemModel`: The power system model containing the component models.
- `u0::Vector{Float64}`: The initial values of the state/algebraic variables.
- `du0::Vector{Float64}`: The initial values of the derivatives of the state variables.
- `disturbances::Vector{Disturbance}`: A vector of disturbances that will be applied to the system.
- `solver`: The differential equation solver that will be used to solve the system.
- `auxiliary_data`: Any additional data that needs to be passed to the solver.

# Constructor
```julia
PowerSystemSimulation(
    power_system_model,
    u0,
    du0;
    disturbances=Disturbance[],
    solver=IDA(),
    auxiliary_data=nothing,
) = new(power_system_model, u0, du0, disturbances, solver, auxiliary_data)
```
"""
mutable struct PowerSystemSimulation
    power_system_model::PowerSystemModel
    u0::Vector{Float64}
    du0::Vector{Float64}
    disturbances::Vector{Disturbance}
    solver
    auxiliary_data

    # Constructor with intitialised dirturbance vector, default solver settings, and nothing for auxiliary data
    PowerSystemSimulation(
        power_system_model,
        u0,
        du0;
        disturbances=Disturbance[],
        solver=IDA(),
        auxiliary_data=nothing,
    ) = new(power_system_model, u0, du0, disturbances, solver, auxiliary_data)
end

mutable struct SimulationStage
    stage_index::Int64
    t_start::Float64
    t_end::Float64
    callbacks::Vector{SciMLBase.DECallback}
    tstops
    perturb_model!::Function
    initial_disturbance::Union{Disturbance,Nothing}

    # Constructor with default empty values for callbacks, tstops, perturb_model!, and initial_disturbance
    SimulationStage(
        stage_index,
        t_start,
        t_end,
        callbacks=[],
        tstops=[],
        (perturb_model!)=perturb_model!,
        initial_disturbance=nothing
    ) = new(stage_index, t_start, t_end, callbacks, tstops, perturb_model!, initial_disturbance)
end