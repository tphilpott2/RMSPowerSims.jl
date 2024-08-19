using RMSPowerSims, DataFrames, CSV, Plots

## Run simulation

# load network
net = parse_network_json(joinpath(dirname(@__DIR__), "data", "example_test_systems", "ieee39.json"))

# prepare SimulationData object
power_system_simulation = prepare_simulation(net)

# define short circuit disturbances at bus 1
power_system_simulation.disturbances = Disturbance[
    BusFault(31, 0.1, restart_simulation=true),
    ClearBusFault(31, 0.2, restart_simulation=true),
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

powerfactory_results = parse_pf_rms(joinpath(dirname(@__DIR__), "data", "ieee39_verification", "powerfactory_timeseries_results"), "Short_Circuit_Bus_31")

pl_Pg_G02 = plot(
    net["t_vec"], net["gen"]["2"]["sol"]["Pg"],
    lw=2, xlims=(0, 10),
    label="RMSPowerSims.jl", frame=:box,
    ylabel="Active Power (p.u.)", xlabel="Time (s)",
    fontfamily="Times Roman", size=(800, 300),
)
plot!(
    powerfactory_results.time, 0.01 .* powerfactory_results[:, "G 02_P1"],
    lw=2, label="PowerFactory", style=:dash
)
pl_V_bus_31 = plot(
    net["t_vec"], net["bus"]["31"]["sol"]["V"],
    lw=2, xlims=(0, 10),
    label="RMSPowerSims.jl", frame=:box,
    ylabel="Voltage (p.u.)", xlabel="Time (s)",
    fontfamily="Times Roman", size=(800, 300),
)
plot!(
    powerfactory_results.time, powerfactory_results[:, "Bus 31_u"],
    lw=2, label="PowerFactory", style=:dash
)

pl_Pg_G09 = plot(
    net["t_vec"], net["gen"]["9"]["sol"]["Pg"],
    lw=2, xlims=(0, 10),
    label="RMSPowerSims.jl", frame=:box,
    ylabel="Active Power (p.u.)", xlabel="Time (s)",
    fontfamily="Times Roman", size=(800, 300),
)
plot!(
    powerfactory_results.time, 0.01 .* powerfactory_results[:, "G 09_P1"],
    lw=2, label="PowerFactory", style=:dash
)

pl_V_bus_38 = plot(
    net["t_vec"], net["bus"]["38"]["sol"]["V"],
    lw=2, xlims=(0, 10),
    label="RMSPowerSims.jl", frame=:box,
    ylabel="Voltage (p.u.)", xlabel="Time (s)",
    fontfamily="Times Roman", size=(800, 300)
)
plot!(
    powerfactory_results.time, powerfactory_results[:, "Bus 38_u"],
    lw=2, label="PowerFactory", style=:dash
)

savefig(pl_Pg_G02, joinpath(dirname(@__DIR__), "data", "ieee39_verification", "Short_Circuit_Bus_31_G02_Pg.png"))
savefig(pl_V_bus_31, joinpath(dirname(@__DIR__), "data", "ieee39_verification", "Short_Circuit_Bus_31_Bus_31_V.png"))
savefig(pl_Pg_G09, joinpath(dirname(@__DIR__), "data", "ieee39_verification", "Short_Circuit_Bus_31_G09_Pg.png"))
savefig(pl_V_bus_38, joinpath(dirname(@__DIR__), "data", "ieee39_verification", "Short_Circuit_Bus_31_Bus_38_V.png"))
