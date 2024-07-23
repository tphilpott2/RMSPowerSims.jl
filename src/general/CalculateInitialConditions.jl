using NLsolve, DataFrames

function calculate_system_ic!(net::Dict{String,Any}; recalculate_load_flow=true)
    # Get var_list
    var_list = get_var_list(net)

    # Initialise u0 and du0
    u0 = zeros(Float64, length(var_list))
    du0 = zeros(Float64, length(var_list)) # du is initialised to zero for all states

    # Assign ω_coi initial condition as 1.0 if centre of inertia reference is selected
    net["dynamic_model_parameters"]["ω_ref"] == "coi" ? u0[1] = 1.0 : nothing

    # Recalculate load flow if required
    if recalculate_load_flow
        # perform load flow
        ldf_result = solve_pf(net, ACPPowerModel, Ipopt.Optimizer)
        update_data!(net, ldf_result["solution"])
    end

    # Add initial values of bus variables to u0 vector
    add_bus_ic!(u0, net, var_list)

    # Add initial values of generator variables to u0 vector
    add_generator_ic!(u0, net, var_list)

    # Add initial values of load variables to u0 vector
    add_load_ic!(u0, net, var_list)

    # # Add initial active and reactive power injections from loads (from load flow solution) to u0 vector
    # Pd_indexes = find_all_variable_indexes(var_list, "Pd")
    # Pd_values = [net["load"]["$load_ind"]["pd"] for load_ind = 1:num_loads]
    # u0[Pd_indexes] = Pd_values

    # Qd_indexes = find_all_variable_indexes(var_list, "Qd")
    # Qd_values = [net["load"]["$load_ind"]["qd"] for load_ind = 1:num_loads]
    # u0[Qd_indexes] = Qd_values

    return (u0, du0)
end

function add_bus_ic!(u0, net::Dict{String,Any}, var_list)
    # Add initial values of bus voltages (from load flow solution) to u0 vector
    num_buses = length(keys(net["bus"]))

    V_indexes = find_all_variable_indexes(var_list, "V")
    V_values = [net["bus"]["$bus_ind"]["vm"] for bus_ind = 1:num_buses]
    u0[V_indexes] = V_values

    θ_indexes = find_all_variable_indexes(var_list, "θ")
    θ_values = [net["bus"]["$bus_ind"]["va"] for bus_ind = 1:num_buses]
    u0[θ_indexes] = θ_values
end

function add_generator_ic!(u0, net, var_list)
    num_gens = length(keys(net["gen"]))
    for gen_ind = 1:num_gens
        add_generator_ic!(u0, net, gen_ind, var_list)
    end
end

function add_generator_ic!(u0, net::Dict{String,Any}, gen_ind, var_list)
    # Extract generator information
    gen = net["gen"]["$gen_ind"]
    gen_model_type = gen["dynamic_model"]["model_type"]

    # Calculate initial values of internal synchronous machine variables
    gen_initial_state = generate_ic!(net, gen_ind, gen_model_type)
    add_ic_to_u0!(u0, gen_initial_state, var_list)

    # Calculate initial values of controller variables
    for controller in values(gen["dynamic_model"]["controllers"])
        controller_initial_state = generate_ic!(net, gen_ind, controller["model_type"])
        add_ic_to_u0!(u0, controller_initial_state, var_list)
    end

    # Check for AVR model and Governor model in synchronous generators
    if gen["dynamic_model"]["model_type"] <: SynchronousGeneratorModel
        # Add constant excitation models if AVR model not present
        has_avr(gen) ? add_ic_to_u0!(
            u0,
            generate_ic!(net, gen_ind, ConstantExcitation),
            var_list,
        ) : nothing
        # Add constant mechanical power model if Governor model not present
        has_gov(gen) ? add_ic_to_u0!(
            u0,
            generate_ic!(net, gen_ind, ConstantMechanicalPower),
            var_list,
        ) : nothing
    end
end

function add_load_ic!(u0, net, var_list)
    num_loads = length(keys(net["load"]))
    for load_ind = 1:num_loads
        add_load_ic!(u0, net, load_ind, var_list)
    end
end

function add_load_ic!(u0, net::Dict{String,Any}, load_ind, var_list)
    # Calculate initial values of load variables
    load_initial_state = generate_ic!(net, load_ind, net["load"]["$load_ind"]["dynamic_model"]["model_type"])
    add_ic_to_u0!(u0, load_initial_state, var_list)
end

function add_ic_to_u0!(u0::Vector{Float64}, initial_state_df::DataFrame, var_list)
    state_indexes = find_variable_indexes(var_list, initial_state_df.names)
    u0[state_indexes] = initial_state_df.values
end
