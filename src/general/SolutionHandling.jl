using DifferentialEquations, DataFrames, OrderedCollections
###########################################################################
# Read DAESolutions
###########################################################################
function get_res_u(net::Dict{String,Any}, soln)
    # Initialise dataframe
    df = DataFrame()
    var_list = get_var_list(net)
    for var in var_list
        df[!, var] = Vector{Float64}(undef, 0)
    end

    # Read solutions
    soln_vector = soln isa DAESolution ? [soln] : soln
    for soln_instance in soln_vector
        for row in soln_instance.u
            push!(df, row)
        end
    end

    # Add time vector
    t_vec = vcat([soln_instance.t for soln_instance in soln_vector]...)
    df = insertcols!(df, 1, :t => t_vec)
    return df
end
function get_res_du(net::Dict{String,Any}, soln)
    # Initialise dataframe
    df = DataFrame()
    var_list = get_var_list(net)
    for var in var_list
        df[!, "d$var"] = Vector{Float64}(undef, 0)
    end

    # Read solutions
    soln_vector = soln isa DAESolution ? [soln] : soln

    for soln_instance in soln_vector
        for row in soln_instance.du
            push!(df, row)
        end
    end

    # Add time vector
    t_vec = vcat([soln_instance.t for soln_instance in soln_vector]...)
    df = insertcols!(df, 1, :t => t_vec)
    return df
end

###########################################################################
# Add data to PowerModels network data dictionary
###########################################################################
function add_simulation_results!(net::Dict{String,Any}, soln)
    # Parse DAE solution to dataframe
    result_df = innerjoin(get_res_u(net, soln), get_res_du(net, soln), on=:t)

    # Add time vector to network dict
    net["t_vec"] = result_df.t


    # Add centre of inertia reference (if selected)
    net["dynamic_model_parameters"]["ω_ref"] == "coi" ? net["ω_coi"] = copy(result_df.ω_coi) : nothing

    # Add generator, bus and load results
    add_gen_results!(net, result_df)
    add_bus_results!(net, result_df)
    add_load_results!(net, result_df)
end

get_all_variables(model_type) = String[
    variables(model_type)
    differential_variables(model_type)
]

function add_gen_results!(net::Dict, res::DataFrame)
    for (g, gen) in net["gen"]
        # Initialise result dict
        gen["sol"] = OrderedDict{String,Any}()
        # Add machine results
        add_res_vecs!(
            gen,
            res,
            get_all_variables(gen["dynamic_model"]["model_type"]),
        )

        # Add controller results
        for controller in values(gen["dynamic_model"]["controllers"])
            add_res_vecs!(
                gen,
                res,
                get_all_variables(controller["model_type"])
            )
        end

    end
end

function add_bus_results!(net::Dict, res::DataFrame)
    for (b, bus) in net["bus"]
        bus["sol"] = Dict{String,Any}()
        add_res_vecs!(bus, res, ["V", "θ"])
    end
end

function add_load_results!(net::Dict, res::DataFrame)
    for (l, load) in net["load"]
        load["sol"] = Dict{String,Any}()
        add_res_vecs!(
            load,
            res,
            get_all_variables(load["dynamic_model"]["model_type"]),
        )
    end
end

function add_res_vec!(elm::Dict, res::DataFrame, var)
    elm["sol"][var] = copy(res[:, "$(var)_$(elm["index"])"])
end

function add_res_vecs!(elm::Dict, res::DataFrame, vars::Vector{String})
    for var in vars
        add_res_vec!(elm, res, var)
    end
end

###########################################################################
# Write simulation results to CSV
###########################################################################
function write_simulation_results(fp::String, soln::DAESolution, net::Dict{String,Any})
    df = get_res_u(net, soln)
    CSV.write(fp, df)
end

