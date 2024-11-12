using RMSPowerSims, DataFrames, CSV, Plots, Measures

## Run simulation

# load network
net = parse_network_json(joinpath(dirname(dirname(@__DIR__)), "data", "example_test_systems", "ieee39.json"))

# prepare SimulationData object
power_system_simulation = prepare_simulation(net)

# define short circuit disturbances at bus 1
power_system_simulation.disturbances = Disturbance[
    BusFault(31, 0.1, restart_simulation=true),
    ClearBusFault(31, 0.2, restart_simulation=true),
    LoadStep(9, 1.5, 0.2 * net["load"]["9"]["pd"]),
]

# run simulation
tspan = (0.0, 20.0)
soln = run_RMS_simulation(
    power_system_simulation,
    tspan;
    reltol=1e-4,
    abstol=1e-4,
    saveat=0.01,
    dense=true,
);

# add results to network data dictionary
add_simulation_results!(net, soln)

# Plot results

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

powerfactory_results = parse_pf_rms(joinpath(dirname(@__DIR__), "data", "ieee39_verification", "powerfactory_timeseries_results"), "short_circuit_and_load_step_results")
##
plot_kwargs = [
    :xlabel => "Time (s)",
    :fontfamily => "Times Roman",
    :size => (800, 200),
    :bottom_margin => (6, :mm),
    :left_margin => (5, :mm),
    :labelfontsize => 12,
    :xtickfontsize => 12,
    :ytickfontsize => 12,
    :frame => :box,
    :lw => 2,
    :xlims => (0, 10),
    :legend => :bottomright,
]


pl_Pg_G02 = plot(
    net["t_vec"], net["gen"]["2"]["sol"]["Pg"],
    label="RMSPowerSims.jl",
    ylabel="Active Power (p.u.)";
    plot_kwargs...,
)
plot!(
    powerfactory_results.time, 0.01 .* powerfactory_results[:, "G 02_P1"],
    lw=2, label="PowerFactory", style=:dash,
)
pl_V_bus_31 = plot(
    net["t_vec"], net["bus"]["31"]["sol"]["V"],
    label="RMSPowerSims.jl",
    ylabel="Voltage (p.u.)";
    plot_kwargs...,
)
plot!(
    powerfactory_results.time, powerfactory_results[:, "Bus 31_u1"],
    lw=2, label="PowerFactory", style=:dash
)

pl_Pg_G09 = plot(
    net["t_vec"], net["gen"]["9"]["sol"]["Pg"],
    label="RMSPowerSims.jl",
    ylabel="Active Power (p.u.)";
    plot_kwargs...,
)
plot!(
    powerfactory_results.time, 0.01 .* powerfactory_results[:, "G 09_P1"],
    lw=2, label="PowerFactory", style=:dash
)

pl_V_bus_38 = plot(
    net["t_vec"], net["bus"]["38"]["sol"]["V"],
    label="RMSPowerSims.jl",
    ylabel="Voltage (p.u.)";
    plot_kwargs...,
)
plot!(
    powerfactory_results.time, powerfactory_results[:, "Bus 38_u1"],
    lw=2, label="PowerFactory", style=:dash
)

plot_Pd_load_16 = plot(
    net["t_vec"], net["load"]["9"]["sol"]["Pd"],
    label="RMSPowerSims.jl",
    ylabel="Active Power (p.u.)";
    plot_kwargs...,
)
plot!(
    powerfactory_results.time, 0.01 .* powerfactory_results[:, "Load 16_Psum_bus1"],
    lw=2, label="PowerFactory", style=:dash
)

display(pl_Pg_G02)
display(pl_V_bus_31)
display(pl_Pg_G09)
display(pl_V_bus_38)
display(plot_Pd_load_16)

# fig_dir = joinpath(dirname(@__DIR__), "data", "ieee39_verification", "figures")
fig_dir = raw"C:\Users\tomph\OneDrive - University of Wollongong\PhD\code\publications\RMSPowerSims_Energies\latex_project\figs"
savefig(pl_Pg_G02, joinpath(fig_dir, "pg_g02.png"))
savefig(pl_V_bus_31, joinpath(fig_dir, "v_bus_31.png"))
savefig(pl_Pg_G09, joinpath(fig_dir, "pg_g09.png"))
savefig(pl_V_bus_38, joinpath(fig_dir, "v_bus_38.png"))
savefig(plot_Pd_load_16, joinpath(fig_dir, "pd_load_16.png"))