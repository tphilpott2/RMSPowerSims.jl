###########################################################################
# Build PowerSystemSimulation object
###########################################################################
function prepare_simulation(net; recalculate_load_flow=true)
    # calculate initial conditions
    (u0, du0) = calculate_system_ic!(net; recalculate_load_flow=true)

    # Build power system model
    power_system_model = PowerSystemModel(
        build_component_list(net),
        get_var_list(net),
        generate_differential_vars(net),
        Dict()
    )

    return PowerSystemSimulation(
        power_system_model,
        u0,
        du0
    )
end

function build_component_list(net::Dict{String,Any})
    # Initialise vectors and collect relevant parameters
    component_list = ComponentModelData[]
    var_list = get_var_list(net)
    num_buses = length(keys(net["bus"]))
    num_gens = length(keys(net["gen"]))
    num_loads = length(keys(net["load"]))

    # Add admittance matrix to net
    net["Y"] = calc_admittance_matrix(net).matrix

    # Build COI reference frequency equations (if selected)
    net["dynamic_model_parameters"]["ω_ref"] == "coi" ?
    add_model_equation_data!(
        component_list,
        net,
        nothing,
        var_list,
        COIReferenceFrequency,
    ) : nothing

    # Build generator equations
    for gen_ind = 1:num_gens
        gen = net["gen"]["$gen_ind"]

        # Add equation data for generator model
        add_model_equation_data!(
            component_list,
            net,
            gen_ind,
            var_list,
            gen["dynamic_model"]["model_type"],
        )

        # Add equation data for any generator controller models
        for controller in values(gen["dynamic_model"]["controllers"])
            add_model_equation_data!(
                component_list,
                net,
                gen_ind,
                var_list,
                controller["model_type"],
            )
        end

        # Check for AVR model and Governor model in synchronous generators
        if gen["dynamic_model"]["model_type"] <: SynchronousGeneratorModel
            # Add constant excitation models if AVR model not present
            !has_avr(gen) ? add_model_equation_data!(
                component_list,
                net,
                gen_ind,
                var_list,
                ConstantExcitation,
            ) : nothing
            # Add constant mechanical power model if Governor model not present
            !has_gov(gen) ? add_model_equation_data!(
                component_list,
                net,
                gen_ind,
                var_list,
                ConstantMechanicalPower,
            ) : nothing
        end
    end

    # Build network equations
    for bus_ind = 1:num_buses
        node_model = make_dynamic_model(net, bus_ind, NodeModel)
        (inds_out, inds_u) =
            make_pointers_to_simulation_variables(net, bus_ind, var_list, NodeModel)
        push!(
            component_list,
            ComponentModelData(
                bus_ind,
                node_model,
                inds_out,
                [],
                inds_u
            ),
        )
    end

    # Build load equations
    for load_ind = 1:num_loads
        load = net["load"]["$load_ind"]
        load_model = make_dynamic_model(net, load_ind, load["dynamic_model"]["model_type"])
        (inds_out, inds_du, inds_u) = make_pointers_to_simulation_variables(
            net,
            load_ind,
            var_list,
            load["dynamic_model"]["model_type"],
        )
        push!(
            component_list,
            ComponentModelData(load_ind, load_model, inds_out, inds_du, inds_u),
        )
    end
    return component_list
end

function add_model_equation_data!(
    component_list,
    net::Dict{String,Any},
    index,
    var_list::Vector{String},
    model_type,
)
    model = make_dynamic_model(net, index, model_type)
    (inds_out, inds_du, inds_u) =
        make_pointers_to_simulation_variables(net, index, var_list, model_type)
    push!(
        component_list,
        ComponentModelData(index, model, inds_out, inds_du, inds_u),
    )
end

###########################################################################
# Make differential variables vector
###########################################################################
function state_variables(model_type, ind)
    if differential_variables(model_type) != []
        return map(x -> pad_with_element_index(x[2:end], ind), differential_variables(model_type))
    else
        return []
    end
end

function generate_differential_vars(net::Dict{String,Any})
    # get all state variables
    state_variable_list = []

    for (g, gen) in net["gen"]
        append!(state_variable_list, state_variables(gen["dynamic_model"]["model_type"], g))
        for (c, controller) in gen["dynamic_model"]["controllers"]
            append!(state_variable_list, state_variables(controller["model_type"], g))
        end
    end
    for (l, load) in net["load"]
        append!(state_variable_list, state_variables(load["dynamic_model"]["model_type"], l))
    end

    return [var ∈ state_variable_list ? true : false for var in get_var_list(net)]
end
