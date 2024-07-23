###########################################################################
# Get var_list 
###########################################################################
function get_var_list(net::Dict{String,Any})
    # Get network dimensions
    num_buses = length(keys(net["bus"]))
    num_gens = length(keys(net["gen"]))
    num_loads = length(keys(net["load"]))

    #Initialise var_list
    var_list = String[]

    # Reference frequency (if centre of inertia reference is selected)
    net["dynamic_model_parameters"]["ω_ref"] == "coi" ? push!(var_list, "ω_coi") : nothing

    # Generator variables
    for gen_ind = 1:num_gens
        gen = net["gen"]["$gen_ind"]
        # Add generator internal variables to var list
        add_model_to_var_list!(var_list, gen_ind, gen["dynamic_model"]["model_type"])

        # check for AVR and Governor models in synchronous generators
        if gen["dynamic_model"]["model_type"] <: SynchronousGeneratorModel
            # add variables for Efd and Tm if control systems are absent
            !has_avr(gen) ? add_model_to_var_list!(var_list, gen_ind, ConstantExcitation) : nothing
            !has_gov(gen) ? add_model_to_var_list!(var_list, gen_ind, ConstantMechanicalPower) : nothing
        end
        # add variables for generator controllers
        for controller in values(gen["dynamic_model"]["controllers"])
            add_model_to_var_list!(var_list, gen_ind, controller["model_type"])
        end

    end

    # Add bus voltage magnitudes and angles to var_list
    append!(var_list, ["V_$bus_ind" for bus_ind = 1:num_buses])
    append!(var_list, ["θ_$bus_ind" for bus_ind = 1:num_buses])

    # Add load powers to var_list
    append!(var_list, ["Pd_$load_ind" for load_ind = 1:num_loads])
    append!(var_list, ["Qd_$load_ind" for load_ind = 1:num_loads])

    return var_list
end

function add_model_to_var_list!(var_list::Vector{String}, element_index, model_type)
    var_names = pad_with_element_index.(variables(model_type), element_index)
    append!(var_list, var_names)
end

get_reference_gen_index(net::Dict{String,Any}) =
    net["dynamic_model_parameters"]["ω_ref"] == "coi" ? "ω_coi" : "ω_$(net["dynamic_model_parameters"]["ω_ref"])"

###########################################################################
# Variable search functions
###########################################################################

# Find index of single var. i.e. "V_1"
function find_variable_index(var_list::Vector{String}, var::String)
    return findfirst(isequal(var), var_list)
end

# Find index of a collection of variables. i.e. ["V_1", "θ_1", "δ_3"]
function find_variable_indexes(var_list::Vector{String}, vars::Vector)
    return [find_variable_index(var_list, var) for var in vars]
end

# Find index of all instances of a variables. i.e. "θ" will return ["θ_1", "θ_2", ..., "θ_n"]
function find_all_variable_indexes(var_list::Vector{String}, var::String)
    return findall(n -> occursin("$(var)_", n), var_list)
end


