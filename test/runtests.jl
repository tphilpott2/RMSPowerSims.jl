using RMSPowerSims
using Test

@testset "RMSPowerSims.jl" begin
    # Write your tests here.
    include("data/example_test_systems/single_gen_network.jl")


    net["load"]["1"]["P"] = 1.9

    power_system_simulation = prepare_simulation(net)

    power_system_simulation.disturbances = Disturbance[
        LoadStep(1, 1.0, 0.1),
    ]

    soln = run_RMS_simulation(
        power_system_simulation,
        (0.0, 10.0);
        solver_settings=Dict(
            "reltol" => 1e-9,
            "abstol" => 1e-8,
            "maxiters" => 10000,
            "dtmax" => 0.01,
        )
    )

    add_simulation_results!(net, soln)

    df = DataFrame(
        :t => net["t_vec"],
        :Pv => net["gen"]["1"]["sol"]["Pv"],
        :dPv => net["gen"]["1"]["sol"]["dPv"],
    )

    df_test = CSV.File("test_01_results.csv") |> DataFrame

    @test isapprox.(df.t, df_test.t)
    @test isapprox.(df.Pv, df_test.Pv)
    @test isapprox.(df.dPv, df_test.dPv)
end
