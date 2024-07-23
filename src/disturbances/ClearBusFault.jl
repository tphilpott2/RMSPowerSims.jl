"""
    BusFault <: Disturbance

Type definition for clearance of a `BusFault`

# Fields
- `bus_ind`: Index of the bus where the fault is to be cleared
- `t_disturbance`: Time at which the disturbance is applied(s)
- `restart_simulation`: Flag indicating whether the simulation should be restarted after applying the disturbance
"""
struct ClearBusFault <: Disturbance
    bus_ind
    t_disturbance
    restart_simulation

    # Constructor with default value for restart_simulation
    ClearBusFault(bus_ind, t_disturbance; restart_simulation=false) = new(bus_ind, t_disturbance, restart_simulation)
end
"""
    perturb_model!(power_system_model::PowerSystemModel, disturbance::BusFault)

Removes a `BusFaultModel` from the `PowerSystemModel` and replaces it with the original `NodeModel`
"""
function perturb_model!(power_system_model::PowerSystemModel, disturbance::ClearBusFault)
    # Get index of faulted bus model data
    faulted_bus_ind = findfirst(n -> n.source_ind == disturbance.bus_ind && n.model isa BusFaultModel, power_system_model.component_list)
    faulted_bus = power_system_model.component_list[faulted_bus_ind]

    # Restore unfaulted bus model data
    power_system_model.component_list[faulted_bus_ind] = faulted_bus.model.unfaulted_model_data
end
