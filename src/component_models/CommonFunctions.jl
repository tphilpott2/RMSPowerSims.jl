# NOTE
# The function definitions in this model are used only to provide common documentation. They are not used in the actual simulation. For this reason, the functions are defined without arguments to ensure that they are not called during the simulation. The actual functions used in the simulation are defined in the individual model files.

"""
    variables(model_type)

Return the unique variable names for the variables in the specified model type.
"""
function variables() end


"""
    differential_variables(model_type)

Return the unique variable names for the differential variables in the specified model type.
"""
function differential_variables() end

"""
    update!(out, du, u, model::ComponentModel, t)

Implementation of the equations that define a component model.

# Arguments
- `out`: Portion of the output (residuals) vector that corresponds to the equations of the component model.
- `du`: Portion of the derivative vector that corresponds to the differential variables of the component model.
- `u`: Portion of the state vector that corresponds to the variables of the component model.
- `model`: An instance of the component model.
- `t`: The current simulation time.

# Note

The method of the update! function that is called is determined by the type of the model argument. The update! function must be defined for each component model type.
"""
function update!() end

"""
    make_dynamic_model(net, ind, model_type::Type{ComponentModel})

Returns an instance of the specified component model type using the parameters in the network data dictionary.

# Arguments
- `net`: The network data dictionary.
- `ind`: The index of the component in the network data dictionary.
- `model_type`: The type of the component model to create.
"""
function make_dynamic_model() end

"""
    make_pointers_to_simulation_variables(net, ind, var_list, model_type::Type{ComponentModel})

Returns the indexes of the variables in the output, derivative, and state vectors that correspond to the component model.

# Arguments
- `net`: The network data dictionary.
- `ind`: The index of the component in the network data dictionary.
- `var_list`: A list of the unique variable names defined for the model.
- `model_type`: The type of the component model.
"""
function make_pointers_to_simulation_variables() end

"""
    generate_ic!(net, ind, model_type::Type{ComponentModel})

Calculates the initial conditions for a component model.

# Arguments
- `net`: The network data dictionary.
- `ind`: The index of the component in the network data dictionary.
- `model_type`: The type of the component model.
"""
function generate_ic!() end

"""
    algebraic_equations!(F, vars, states, model::ComponentModel)

Implementation of the algebraic equations that define a component model. Used during recalculation of system state.

# Arguments
- `F`: The output vector that contains the residuals of the algebraic equations.
- `vars`: The algebraic variables of the component model.
- `states`: The state variables relevant to calculation of the component model algebraic variables.
- `model`: An instance of the component model.
"""
function algebraic_equations!() end

"""
    calculate_state_derivatives!(du, u, model::ComponentModel, inds_du, inds_u)

Calculates the derivatives of the state variables of a component model and updates the derivative vector.

# Arguments
- `du`: The derivative vector.
- `u`: The state vector.
- `model`: An instance of the component model.
- `inds_du`: The indexes of the differential variables in the derivative vector.
- `inds_u`: The indexes of the variables in the state vector.
"""
function calculate_state_derivatives!() end
