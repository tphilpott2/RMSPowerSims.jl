import powerfactory
from time import perf_counter
from pathlib import Path
import csv


# configures the ElmRes file with the elements and variables defined in export_data
def configure_ElmRes(app, export_data, results_file_name, target=None):
    # Get target directory
    if target is None:
        target = app.GetActiveStudyCase()
    # Delete if file exists
    results_file_search = target.GetContents(f"{results_file_name}.ElmRes")
    if results_file_search != []:
        results_file = results_file_search[0]
        results_file.Delete()
    # Create results file
    results_file = target.CreateObject("ElmRes")
    results_file.loc_name = results_file_name

    # add result variables from export_data
    for set_name, set_data in export_data.items():
        for elm in set_data["elms"]:
            for var in set_data["vars"]:
                results_file.AddVariable(elm, var)
        app.PrintInfo(
            f"Added {len(set_data['vars'])} variables for {len(set_data['elms'])} elements in set {set_name}"
        )

    return results_file


# creates or gets the IntEvt file
def make_IntEvt(app, events_file_name, target=None):
    # Get target directory
    if target is None:
        target = app.GetActiveStudyCase()
    # Get or create events file
    events_file_search = target.GetContents(f"{events_file_name}.IntEvt")
    if events_file_search != []:
        events_file = events_file_search[0]
        events_file.Delete()
    # Create events file
    events_file = target.CreateObject("IntEvt")
    events_file.loc_name = events_file_name
    # Clear existing contents
    for event in events_file.GetContents():
        event.Delete()

    return events_file


# makes short circuit event
def make_event_EvtShc(app, events_file, bus, event_parameters, event_name=None):
    event = events_file.CreateObject("EvtShc")
    if event_name is not None:
        event.loc_name = event_name
    else:
        event.loc_name = f"Short Circuit Event - {bus.loc_name}"

    # Set bus
    event.SetAttribute("p_target", bus)

    # Set event parameters
    for param, value in event_parameters.items():
        event.SetAttribute(param, value)

    return event


# makes short circuit and clearance event
def make_event_short_circuit_and_clearance(app, events_file, bus, t_fault, t_clear):
    # Make short circuit event
    make_event_EvtShc(
        app,
        events_file,
        bus,
        {
            "time": t_fault,
            "i_shc": 0,  # 3 phase short circuit
        },
        f"Short Circuit - {bus.loc_name}",
    )
    # Make clearance event
    make_event_EvtShc(
        app,
        events_file,
        bus,
        {
            "time": t_clear,
            "i_shc": 4,  # clear 3 phase short circuit
        },
        f"Short Circuit Clearance - {bus.loc_name}",
    )


# input options
n_runs = 100
sim_time = 50.0
short_circuit_bus_name = "Bus 31"
package_dir = Path(__file__).parent.parent.parent
output_dir = package_dir / "data" / "computation_time_results"
output_file_name = "powerfactory_short_circuit.csv"

if __name__ == "__main__":
    app = powerfactory.GetApplication()

    # configure results file
    export_data = {
        "ElmSym": {
            "elms": app.GetCalcRelevantObjects("*.ElmSym", 0),
            "vars": [
                # "s:P1",
                # "s:Q1",
                # "c:id",
                # "c:iq",
                "s:psi1d",
                "s:psifd",
                "s:psi1q",
                "s:psi2q",
                "s:speed",
                "s:phi",
                "s:psi1d:dt",
                "s:psifd:dt",
                "s:psi1q:dt",
                "s:psi2q:dt",
                "s:speed:dt",
                "s:phi:dt",
            ],
        },
        "ElmTerm": {
            "elms": app.GetCalcRelevantObjects("*.ElmTerm", 0),
            "vars": ["m:u1", "m:phiu"],
        },
        "ElmLod": {
            "elms": app.GetCalcRelevantObjects("*.ElmLod", 0),
            "vars": ["m:Psum:bus1", "m:Qsum:bus1"],
        },
        "IEEET1": {
            "elms": [
                dsl
                for dsl in app.GetCalcRelevantObjects("*.ElmDsl", 0)
                if "AVR" in dsl.loc_name
            ],
            "vars": [
                "s:xe",
                "s:xr",
                "s:xf",
                "s:xa",
                "s:xe:dt",
                "s:xr:dt",
                "s:xf:dt",
                "s:xa:dt",
            ],
        },
        "TGOV1": {
            "elms": [
                dsl
                for dsl in app.GetCalcRelevantObjects("*.ElmDsl", 0)
                if "GOV" in dsl.loc_name
            ],
            "vars": ["s:pt", "s:x1", "s:pt:dt", "s:x1:dt"],
        },
    }
    results_file = configure_ElmRes(
        app,
        export_data,
        f"results_short_circuit",
    )

    # make short circuit event
    events_file = make_IntEvt(app, "short_circuit_event")
    bus = app.GetCalcRelevantObjects(f"*{short_circuit_bus_name}.ElmTerm", 0)[0]
    make_event_short_circuit_and_clearance(app, events_file, bus, 0.1, 0.2)

    # get and configure commands
    cominc = app.GetFromStudyCase("*.ComInc")
    cominc.SetAttribute("alpha_rms", 1)
    cominc.SetAttribute("iopt_adapt", 1)
    cominc.SetAttribute("p_event", events_file)
    cominc.SetAttribute("p_resvar", results_file)
    comsim = app.GetFromStudyCase("*.ComSim")
    comsim.SetAttribute("tstop", sim_time)

    # initialize time vectors
    time_vec_adaptive = []
    time_vec_fixed = []

    # run benchmark for adaptive time steps
    for i in range(n_runs):
        cominc.Execute()
        tstart = perf_counter()
        comsim.Execute()

        tstop = perf_counter()
        time_vec_adaptive.append(tstop - tstart)

    # run benchmark for fixed time steps
    cominc.SetAttribute("iopt_adapt", 0)
    for i in range(n_runs):
        cominc.Execute()
        tstart = perf_counter()
        comsim.Execute()

        tstop = perf_counter()
        time_vec_fixed.append(tstop - tstart)

    # save results to csv
    with open(output_dir / output_file_name, "w", newline="") as f:
        writer = csv.writer(f)
        header = ["adaptive", "fixed"]
        writer.writerow(header)
        for i in range(n_runs):
            writer.writerow([time_vec_adaptive[i], time_vec_fixed[i]])
