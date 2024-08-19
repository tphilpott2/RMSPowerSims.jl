using RMSPowerSims, DataFrames, CSV, Plots

## Run simulation

# load network
net = parse_network_json(joinpath(dirname(@__DIR__), "data", "example_test_systems", "ieee39.json"))

# prepare SimulationData object
power_system_simulation = prepare_simulation(net)

# define load step disturbance at bus 16 (load 16 in ieee39 model, index 9 in powermodels model)
power_system_simulation.disturbances = Disturbance[
    LoadStep(9, 0.1, 0.2 * net["load"]["9"]["pd"]),
]

# run simulation
tspan = (0.0, 15.0)
soln = run_RMS_simulation(
    power_system_simulation,
    tspan;
    solver_settings=Dict(
        "reltol" => 1e-9,
        "abstol" => 1e-8,
        "maxiters" => 10000,
        "dtmax" => 0.01,
    )
);

# add results to network data dictionary
add_simulation_results!(net, soln)

## Plot results

# functions to parse PowerFactory results
function parse_pf_header(fp_header::String)
    df = DataFrame(
        :col => Vector{String}(undef, 0),
        :elm => Vector{String}(undef, 0),
        :var => Vector{String}(undef, 0),
    )

    open(fp_header) do file
        elm = "time"
        for (idx, line) in enumerate(eachline(file))
            idx <= 2 ? continue : nothing   # skip preamble
            if startswith(line, "\\") || startswith(line, "'") # get elm from elm data lines
                elm_with_class = split(line, "\\")[end]
                elm = split(elm_with_class, ".")[1]
            else
                cells = split(line, ",")[1:2]
                push!(df, [
                    cells[1],   # column
                    elm,
                    cells[2],   # var
                ])
            end
        end
    end

    return df
end
function parse_pf_rms(fp::String, header_df::DataFrame)
    df = CSV.File(fp, header=1:2) |> DataFrame
    header_df.var = [join(split(var, ":")[2:end], "_") for var in header_df.var] # remove variable set
    # header_df.var = [split(var, ":")[2] for var in header_df.var] # remove variable set
    nms = ["$(row.elm)_$(row.var)" for row in eachrow(header_df)] # join elm and variable
    nms[1] = "time" # first column is time
    rename!(df, nms)
    return df
end
function parse_pf_rms(folder_path::String, file_name::String)
    fp_header = joinpath(folder_path, "header_$(file_name).csv")
    fp_file = joinpath(folder_path, "$(file_name).csv")
    header_df = parse_pf_header(fp_header)
    df = parse_pf_rms(fp_file, header_df)
    return df
end
function plot_pf!(df::DataFrame, var::String; kwargs...)
    plot!(df.time, df[:, var], label=var, lw=2; kwargs...)
end
function plot_pf!(f::Function, df::DataFrame, var::String; kwargs...)
    return plot!(df.time, f.(df[:, var]), label=var, lw=2; kwargs...)
end

powerfactory_results = parse_pf_rms(joinpath(dirname(@__DIR__), "data", "ieee39_verification", "powerfactory_timeseries_results"), "Load_16_Step")

pl_Pg_load_16 = plot(
    net["t_vec"], net["load"]["9"]["sol"]["Pd"],
    lw=2, xlims=(0, 10),
    label="RMSPowerSims.jl", frame=:box,
    ylabel="Active Power (p.u.)", xlabel="Time (s)",
    fontfamily="Times Roman", size=(800, 300),
)
plot_pf!(n -> n / 100, powerfactory_results, "Load 16_Psum_bus1") # convert to p.u.
savefig(pl_Pg_load_16, joinpath(dirname(@__DIR__), "data", "ieee39_verification", "Load_step_load_16_load_16_Pd.png"))
