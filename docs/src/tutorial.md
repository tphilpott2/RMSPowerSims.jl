# Tutorial

This section will provide an example showing how to run time domain simulation using RMSPowersims.

## Defining The Network

The first step is to import some model in the PowerModels.jl network data dictionary (NDD) format, for example

    import PowerModels

    net = PowerModels.parse_matpower("single_generator_network.m")

A properly configured PowerModels.jl model should contain all necessary data for steady-state analysis. It is required to add the data required for dynamic simulation. The additional information required by RMSPowerSims is outlined below

##### Add Model settings

An additional Dict must be added in the top level of the NDD specifying the nominal frequency of the system and the index reference machine for dynamic simulation. The for a 50Hz system and generator "1" as a reference, this can be added using

    net["dynamic_model_parameters"] = Dict{String,Any}(
        "ω_ref" => "1",
        "f_nom" => 50.0,
    ),

##### Add Generator Data

Each "gen" entry in the NDD requires a Dict of the following form to be added

    "dynamic_model" => Dict{String,Any}(
        "model_type" => model_type::GeneratorModel,
        "parameters" => Dict{String,Any}(),
        "controllers" => Dict{Any,Any}(),
        ),

- The "model_type" entry specifies the model that will be used for the generator, i.e. `SixthOrderModel`.
- The "parameters" entry contains all parameters for simulation of the selected generator model.
- The "controllers" entry contains Dicts with the data required for simulation of each controller. Keys to the controller dict should have the same name as the `ControllerModel`.

The code excerpt below configures generator "1" as a `SixthOrderModel` with an `IEEET1` AVR model and a `TGOV1` governor model.

    net["gen"]["1"]["dynamic_model"] -Dict{String,Any}(
        "model_type" => SixthOrderModel,
        "parameters" => Dict{String,Any}(
            "ωs" => 1,
            "H" => 1.3,
            "Xl" => 0.172,
            "Rs" => 0.0,
            "Xq" => 2.0,
            "Xq_d" => 0.3,
            "Xq_dd" => 0.2,
            "Xd" => 2.0,
            "Xd_d" => 0.3,
            "Xd_dd" => 0.2,
            "Tq_d" => 6.66667,
            "Td_dd" => 0.075,
            "Td_d" => 6.66667,
            "Tq_dd" => 0.075,
            "consider_ωr_variations" => true,
        ),
        "controllers" => Dict{String,Any}(
            "IEEET1" => Dict{String,Any}(
                "model_type" => IEEET1,
                "parameters" => Dict{String,Any}(
                    "Te" => 0.2,
                    "Ta" => 0.03,
                    "Tf" => 1.5,
                    "Tr" => 0.02,
                    "Ke" => 1.0,
                    "Ka" => 200,
                    "Kf" => 0.05,
                    "E1" => 3.036,
                    "Se1" => 0.66,
                    "E2" => 4.048,
                    "Se2" => 0.88,
                    "Vrmin" => -10.0,
                    "Vrmax" => 10.0,
                ),
            ),
            "TGOV1" => Dict{String,Any}(
                "model_type" => TGOV1,
                "parameters" => Dict{String,Any}(
                    "T1" => 0.5,
                    "T2" => 2.1,
                    "T3" => 7.0,
                    "Rd" => 0.05,
                    "Vmin" => 0.0,
                    "Vmax" => 1.0,
                ),
            ),
        ),
    )

    net["gen"]["1"]["mbase"] = 200
    net["gen"]["1"]["vbase"] = 23

Note that for the `SixthOrderModel` generator it is also required to specify rated power and voltage of the machine.

##### Add Load Data

The process for adding load data is similar to that of generator data. Each load entry must include a Dict in the following form

    "dynamic_model" => Dict{String,Any}(
        "model_type" => model_type::LoadModel,
        "parameters" => Dict{String,Any}(),
    )
    
The following code excerpt configures load "1" as constant impedance using the `ZIPLoad` model

    net["load"]["1"] = Dict{String,Any}(
        "model_type" => ZIPLoad,
        "parameters" => Dict{String,Any}(
            "Kpz" => 1.0,
            "Kpi" => 0.0,
            "Kqz" => 1.0,
            "Kqi" => 0.0,
        ),
    )

## Configuring the PowerSystemSimulation

The PowerSystemSimulation object that will be passed to the differential equation solver is parsed directly from the NDD using the function `prepare_simulation`. It is during this function call that the initial conditions for the simulation are calculated

    using RMSPowerSims

    power_system_simulation = prepare_simulation(net)

## Defining Disturbances

Each disturbance is defined as an instance of some subtype of the `Disturbance` type. These are then added to the `disturbances` field of the `PowerSystemSimulation`. The following code excerpt defines a bolted short circuit at bus "3", which occurs at t = 0.5s. The fault is then cleared at t = 0.56s.

    power_system_simulation.disturbances = Disturbance[
        BusFault(3, 0.5),
        ClearBusFault(3, 0.56, restart_simulation=true),
    ]

Note tha the `restart_simulation` field of `ClearBusFault` is set to true. This will cause the simulation to be stopped at the time of the fault, the state of the system to be recalculated, and a new simulation to be started. This can be useful for disturbances that introduce significant discontinuities for which the solver fails to converge.

## Executing a Simulation

A simulation is executed using the function `run_RMS_simulation`. Settings to be passed to the solver are hardcoded using the `"solver_settings"` Dict.

    tspan = (0.0, 5.0)
    soln = run_RMS_simulation(
        power_system_simulation,
        tspan;
        solver_settings=Dict(
            "reltol" => 1e-9,
            "abstol" => 1e-8,
            "maxiters" => 2000,
            "dtmax" => 0.01,
        )
    );

Since the option of `restart_simulation` is selected for at least one fault, this means that the simulation will be performed in multiple stages. Note that settings are passed to the solver for each additional in this stage, so in this instance, the maximum iterations would be 2000 per stage.

## Accessing results

The solution returned from `run_RMS_simulation` can be appended directly to the NDD using

    add_simulation_results!(net, soln)

The results are added in an additional Dict for each element, with the key "sol". For example, the time series solution for the Voltage at bus "1" is accessed as

    bus_voltage = net["bus"]["1"]["sol"]["V"]

The variable ID, in this case "V", is defined as a part of the component model.

It is also worth noting that generator controller results are added directly to the "sol" Dict of the generator. For example, the valve position of the governor is accessed as

    valve_position = net["gen"]["1"]["sol"]["Pv"]

The time steps can be accessed from the NDD as

    time_steps = net["t_vec"]

##### Plotting

Time series results of a variable can easily be plotted using the `plot_res` function. Keyword arguments supported by the Plots.jl package can be passed directly

    using Plots

    plot_res(net, "gen", "1", "Pg", xlims = (0.0,2.0))
