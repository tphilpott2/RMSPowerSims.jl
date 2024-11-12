using Plots, DataFrames, CSV
using StatsBase, StatsPlots
package_dir = (@__DIR__) |> dirname |> dirname

# load data
no_disturbance_time_df = CSV.read(joinpath(package_dir, "data", "computation_time_results", "computation_time_no_disturbance.csv"), DataFrame)
short_circuit_time_df = CSV.read(joinpath(package_dir, "data", "computation_time_results", "computation_time_short_circuit.csv"), DataFrame)
load_step_time_df = CSV.read(joinpath(package_dir, "data", "computation_time_results", "computation_time_load_step.csv"), DataFrame)
powerfactory_no_disturbance_time_df = CSV.read(joinpath(package_dir, "data", "computation_time_results", "powerfactory_no_disturbance.csv"), DataFrame)
powerfactory_short_circuit_time_df = CSV.read(joinpath(package_dir, "data", "computation_time_results", "powerfactory_short_circuit.csv"), DataFrame)
powerfactory_load_step_time_df = CSV.read(joinpath(package_dir, "data", "computation_time_results", "powerfactory_load_step.csv"), DataFrame)


function time_plot(data, data_pf; kwargs...)
    return violin(
        ["RMSPowerSims\n(Fixed)" "PowerFactory\n(Fixed)" "RMSPowerSims\n(Adaptive)" "PowerFactory\n(Adaptive)"],
        [data.fixed data_pf.fixed data.adaptive data_pf.adaptive];
        kwargs...
    )
end
plot_kwargs = [
    :ylabel => "Time (s)",
    :outliers => false,
    :label => false,
    :whisker_width => :match,
    :bar_width => 0.5,
    :framestyle => :box,
    :size => (800, 400),
    :left_margin => (5, :mm),
    :bottom_margin => (5, :mm),
    :fontfamily => "Times Roman",
    :labelfontsize => 12,
    :xtickfontsize => 12,
    :ytickfontsize => 12,
]
# :xlims => (-0.5, 2.5),
log_kwargs = [
    :grid => true,
    :yscale => :log10,
]
yt_load_step = 0.1:0.1:0.9
pl_load_step_log = time_plot(
    load_step_time_df,
    powerfactory_load_step_time_df;
    plot_kwargs...,
    log_kwargs...,
    yticks=(yt_load_step, yt_load_step),
    ylims=(minimum(yt_load_step), maximum(yt_load_step)))
yt_short_circuit = [
    0.1,
    0.2,
    0.5,
    1.0,
    2.0,
    5.0,
]
pl_short_circuit_log = time_plot(
    short_circuit_time_df,
    powerfactory_short_circuit_time_df;
    plot_kwargs...,
    log_kwargs...,
    yticks=(yt_short_circuit, yt_short_circuit),
    ylims=(minimum(yt_short_circuit), maximum(yt_short_circuit))
)
pl_load_step_log |> display
out_dir = raw"C:\Users\tomph\OneDrive - University of Wollongong\PhD\code\publications\RMSPowerSims_Energies\latex_project\figs"
savefig(pl_load_step_log, joinpath(out_dir, "computation_time_load_step_logscale.png"))
savefig(pl_short_circuit_log, joinpath(out_dir, "computation_time_short_circuit_logscale.png"))
##
# Create boxplot for no disturbance scenario
pl_load_step = time_plot(
    load_step_time_df,
    powerfactory_load_step_time_df;
    plot_kwargs...,
)
pl_short_circuit = time_plot(
    short_circuit_time_df,
    powerfactory_short_circuit_time_df;
    plot_kwargs...,
)
savefig(pl_load_step, joinpath(out_dir, "computation_time_load_step.png"))
savefig(pl_short_circuit, joinpath(out_dir, "computation_time_short_circuit.png"))