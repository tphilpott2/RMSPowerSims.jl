using DataFrames
###########################################################################
# Recalculate system state
###########################################################################

function recalculate_system_state(component_list, u0, var_list, differential_vars)
    #push!(time_tracker, ["State recalc started", time_ns()])
    # Initialise u and du vectors
    u = Vector{Any}(undef, length(var_list))
    du = Vector{Any}(undef, length(var_list))

    # Define state variables as constant at time of fault
    u = [is_differential ? var : nothing for (is_differential, var) in zip(differential_vars, u0)]

    # Recaclulate algebraic variables
    recalculate_algebraic_variables!(u, component_list, var_list, differential_vars)

    #push!(time_tracker, ["Algebraic vars recalculated", time_ns()])

    # Set algebraic variable derivatives to zero (for conversion to float64)
    du = [is_differential ? nothing : 0.0 for is_differential in differential_vars]

    # Recalculate derivatives of state variables
    for component_model in component_list
        if length(differential_variables(typeof(component_model.model))) != 0
            calculate_state_derivatives!(du, u, component_model.model, component_model.inds_du, component_model.inds_u)
        end
    end
    #push!(time_tracker, ["derivatives recalculated", time_ns()])

    # Convert to Float64
    u = convert.(Float64, u)
    du = convert.(Float64, du)

    return u, du
end

function recalculate_algebraic_variables!(u, component_list, var_list, differential_vars)
    #push!(time_tracker, ["Algebraic var calc started", time_ns()])
    # Define var lists for algebraic variables and state variables
    state_var_list = [var_list[i] for i in 1:length(var_list) if differential_vars[i]]
    algebraic_var_list = [var_list[i] for i in 1:length(var_list) if !differential_vars[i]]

    # Create maps from each variable to its index in the algebraic/state variable lists
    global_var_to_algebraic_var_map = Dict()
    for (i, var) in enumerate(var_list)
        global_var_to_algebraic_var_map[i] = var in algebraic_var_list ? findfirst(x -> x == var, algebraic_var_list) : nothing
    end
    global_var_to_state_var_map = Dict()
    for (i, var) in enumerate(var_list)
        global_var_to_state_var_map[i] = var in state_var_list ? findfirst(x -> x == var, state_var_list) : nothing
    end
    #push!(time_tracker, ["Maps created", time_ns()])

    # Initial guess for the variables
    states = u[find_variable_indexes(var_list, state_var_list)]

    initial_guess = make_initial_guess(algebraic_var_list)
    #push!(time_tracker, ["Initial guess made", time_ns()])

    # Define algebraic equations
    function system_algebraic_model!(F, vars)
        for component_model in component_list
            if length(variables(typeof(component_model.model))) != length(differential_variables(typeof(component_model.model)))
                # Get indexes of variables in the algebraic and state variable lists
                inds_F = map(x -> global_var_to_algebraic_var_map[x], component_model.inds_out)
                inds_vars = map(x -> global_var_to_algebraic_var_map[x], component_model.inds_u)
                inds_states = map(x -> global_var_to_state_var_map[x], component_model.inds_u)
                filter!.(!isnothing, [inds_F, inds_vars, inds_states])

                # Algebraic equations for each component model
                algebraic_equations!(@view(F[inds_F]), vars[inds_vars], states[inds_states], component_model.model)
            end
        end
    end
    #push!(time_tracker, ["Function defined", time_ns()])
    # Solve the system
    solution = nlsolve(system_algebraic_model!, initial_guess)
    #push!(time_tracker, ["Algebraic model solved", time_ns()])

    if solution.f_converged
        u[find_variable_indexes(var_list, algebraic_var_list)] = solution.zero
    else
        println("Recalculation of system state failed")
    end
end

function make_initial_guess(algebraic_var_list)
    # Initalise initial guess vector
    initial_guess = zeros(length(algebraic_var_list))

    # Set initial guess for voltage variables to be one
    for (i, var) in enumerate(algebraic_var_list)
        if split(var, "_")[1] == "V"
            initial_guess[i] = 1.0
        end
    end
    return initial_guess
end