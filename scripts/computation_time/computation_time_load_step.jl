using RMSPowerSims, DataFrames, CSV

package_dir = (@__DIR__) |> dirname |> dirname
tspan = (0.0, 50.0)
n_runs = 100

# prepare simulation
net = parse_network_json(joinpath(package_dir, "data", "example_test_systems", "ieee39.json"))
power_system_simulation = prepare_simulation(net)
power_system_simulation.disturbances = Disturbance[
    LoadStep(9, 1.5, 0.2 * net["load"]["9"]["pd"]),
]

# initialize time vectors
time_vec_fixed = []
time_vec_adaptive = []

# Warm-up run
for i in 1:1
    run_power_system_simulation = deepcopy(power_system_simulation)
    res = run_RMS_simulation(
        run_power_system_simulation,
        tspan;
        :reltol => 1e-4,
        :abstol => 1e-4,
        :dtmax => 0.01,
        :adaptive => false,
    )
end

# benchmark for fixed time steps
for i in 1:n_runs
    tstart = time_ns()
    run_power_system_simulation = deepcopy(power_system_simulation)
    res = run_RMS_simulation(
        run_power_system_simulation,
        tspan;
        :reltol => 1e-4,
        :abstol => 1e-4,
        :dtmax => 0.01,
        :adaptive => false,
    )
    tstop = time_ns()
    push!(time_vec_fixed, (tstop - tstart) * 1e-9)
end

# benchmark for adaptive time steps
for i in 1:n_runs
    tstart = time_ns()
    run_power_system_simulation = deepcopy(power_system_simulation)
    res = run_RMS_simulation(
        run_power_system_simulation,
        tspan;
        :reltol => 1e-4,
        :abstol => 1e-4,
        :dtmax => 0.1,
        :adaptive => true,
    )
    tstop = time_ns()
    push!(time_vec_adaptive, (tstop - tstart) * 1e-9)
end

# save results
load_step_time_df = DataFrame(
    fixed=time_vec_fixed,
    adaptive=time_vec_adaptive,
)
CSV.write(joinpath(package_dir, "data", "computation_time_results", "computation_time_load_step.csv"), load_step_time_df)
