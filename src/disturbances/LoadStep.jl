"""
    LoadStep <: Disturbance

Type definition for a disturbance that applies a step change in the active power demand of a load component.

# Fields
- `load_ind`: Index of the load component in the network data dictionary
- `t_disturbance`: Time at which the disturbance is applied(s)
- `ΔP`: Change in active power demand (p.u.)
- `restart_simulation`: Flag indicating whether the simulation should be restarted after applying the disturbance
"""
struct LoadStep <: Disturbance
    load_ind
    t_disturbance
    ΔP
    restart_simulation

    # Constructor with default value for restart_simulation
    LoadStep(load_ind, t_disturbance, ΔP; restart_simulation=false) = new(load_ind, t_disturbance, ΔP, restart_simulation)
end

"""
    perturb_model!(power_system_model::PowerSystemModel, disturbance::LoadStep)

Applies a step change in the active power demand of a load component in the PowerSystemModel.
"""
function perturb_model!(power_system_model::PowerSystemModel, disturbance::LoadStep)
    # Find load equations in component_list
    load_model_ind = findfirst(component_model -> component_model.source_ind == disturbance.load_ind && component_model.model isa LoadModel, power_system_model.component_list)

    # Apply load step
    power_system_model.component_list[load_model_ind].model.Pd0 += disturbance.ΔP
end
