###########################################################################
# Functions for executing RMS simulation
###########################################################################
function power_system_equations!(out, du, u, p, t)
    # Extract equations
    component_list = p.component_list

    for component_model in component_list
        update!(@view(out[component_model.inds_out]), du[component_model.inds_du], u[component_model.inds_u], component_model.model, t)
    end
end

# kwargs are passed only to the solver
function run_RMS_simulation(power_system_simulation, tspan::Tuple{Float64,Float64}; solver_settings=Dict())


    # configure stages
    #push!(time_tracker, ["Simulation Start", time_ns()])
    stages = configure_stages(power_system_simulation, tspan)
    #push!(time_tracker, ["Stages Configures", time_ns()])

    # run first stage 
    start_time = time_ns()
    #push!(time_tracker, ["Stages Configures", time_ns()])
    first_stage = stages[1]
    prob = DAEProblem(
        power_system_equations!,
        power_system_simulation.du0,
        power_system_simulation.u0,
        (tspan[1], first_stage.t_end),
        power_system_simulation.power_system_model,
        differential_vars=power_system_simulation.power_system_model.differential_vars,
        tstops=first_stage.tstops,
    )
    #push!(time_tracker, ["Stage 1 problem defined", time_ns()])
    soln = solve(
        prob,
        power_system_simulation.solver,
        callback=CallbackSet(first_stage.callbacks...),
        reltol=solver_settings["reltol"],
        abstol=solver_settings["abstol"],
        dtmax=solver_settings["dtmax"],
        maxiters=solver_settings["maxiters"],
    )
    #push!(time_tracker, ["Stage 1 executed", time_ns()])
    # pr("stage 1 complete: $((time_ns() - start_time)*1e-9) s\n")
    if soln.retcode != ReturnCode.Success
        println("Simulation failed at stage 1")
        print_solution_info(soln, start_time)
        return soln
    end

    # check for additional stages
    if length(stages) == 1
        println("Simulation completed successfully")
        print_solution_info(soln, start_time)
        return soln
    else
        solns = DAESolution[soln]
        for stage in stages[2:end]
            # Apply disturbance to power system model
            perturb_model!(power_system_simulation.power_system_model, stage.initial_disturbance)
            # pr("state recalc started: $((time_ns() - start_time)*1e-9) s\n")
            #push!(time_tracker, ["model perturbed", time_ns()])

            (u, du) = recalculate_system_state(
                power_system_simulation.power_system_model.component_list,
                solns[end].u[end],
                power_system_simulation.power_system_model.variables,
                power_system_simulation.power_system_model.differential_vars
            )
            # pr("state recalc complete: $((time_ns() - start_time)*1e-9) s\n")
            #push!(time_tracker, ["state recalc complete", time_ns()])

            # Run stage
            prob = DAEProblem(
                power_system_equations!,
                du,
                u,
                (stage.t_start, stage.t_end),
                power_system_simulation.power_system_model,
                differential_vars=power_system_simulation.power_system_model.differential_vars,
                tstops=stage.tstops,
            )
            #push!(time_tracker, ["stage $(stage.stage_index) problem defined", time_ns()])

            soln = solve(
                prob,
                power_system_simulation.solver,
                callback=CallbackSet(stage.callbacks...),
                reltol=solver_settings["reltol"],
                abstol=solver_settings["abstol"],
                dtmax=solver_settings["dtmax"],
                maxiters=solver_settings["maxiters"],
            )
            # pr("stage $(stage.stage_index) complete: $((time_ns() - start_time)*1e-9) s\n")
            #push!(time_tracker, ["stage $(stage.stage_index) complete", time_ns()])

            push!(solns, soln)

            if soln.retcode != ReturnCode.Success
                println("Simulation failed at stage ", stage.stage_index)
                print_solution_info(soln, start_time)
                return solns
            end
        end

        println("Simulation completed successfully")
        print_solution_info(soln, start_time)
        return solns
    end
end

function print_solution_info(soln, start_time)
    println("retcode: ", soln.retcode)
    println("Time elapsed = ", (time_ns() - start_time) / 1e9, " seconds")
end

###########################################################################
# Functions for configuring multiple stage simulations
###########################################################################

function configure_stages(power_system_simulation, tspan)
    # initialise stage list
    stages = []

    # create stage 1
    current_stage = SimulationStage(
        1,
        tspan[1],
        tspan[2]
    )

    # parse disturbances
    for disturbance in power_system_simulation.disturbances
        if !disturbance.restart_simulation # simulation not restarted
            push!(current_stage.callbacks, create_callback(disturbance))
            push!(current_stage.tstops, disturbance.t_disturbance)
        else
            # terminate current stage
            current_stage.t_end = disturbance.t_disturbance
            push!(stages, current_stage)
            # configure new stage
            new_stage = SimulationStage(
                current_stage.stage_index + 1,
                disturbance.t_disturbance + 1e-5,
                tspan[2],
            )
            new_stage.initial_disturbance = disturbance
            current_stage = new_stage
        end
    end
    push!(stages, current_stage)
end

"""
    perturb_model!(power_system_model::PowerSystemModel, disturbance::Disturbance)

Modify the power system model in accordance with the specified disturbance.

# Arguments
- `power_system_model::PowerSystemModel`: Power system model to be modified
- `disturbance::Disturbance`: Disturbance to be applied to the power system model
"""
function perturb_model!() end # This function method is defined only for documentation purposes and should not be called

"""
    create_callback(disturbance::Disturbance)

Create a callback function that applies the disturbance at the time specified.

# Arguments
- `disturbance::Disturbance`: Disturbance to be applied
"""
function create_callback(disturbance::Disturbance)
    # Make flag
    fault_triggered = false

    # Make event trigger
    function condition(u, t, integrator)
        t == disturbance.t_disturbance && !fault_triggered
    end

    # Event action function
    function affect!(integrator)
        # Modify load equations
        perturb_model!(integrator.p, disturbance)

        # Set event flag as triggered
        fault_triggered = true
    end

    # Create the callback
    return DiscreteCallback(condition, affect!)
end