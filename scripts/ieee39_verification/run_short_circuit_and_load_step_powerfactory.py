import math
import cmath
import csv
import sys
import os
from pathlib import Path
import powerfactory

app = powerfactory.GetApplication()
app.ClearOutputWindow()


def pr(x):
    app.PrintInfo(x)
    print(x)


# create study case
def create_study_case(app, study_case_name):
    study_folder = app.GetProjectFolder("study")
    # delete existing study case if it exists
    if study_folder.GetContents(f"{study_case_name}.IntCase") is not []:
        study_case = study_folder.GetContents(f"{study_case_name}.IntCase")[0]
        study_case.Deactivate()
        study_case.Delete()
    # create study case
    study_case = study_folder.CreateObject("IntCase")
    study_case.loc_name = study_case_name
    study_case.Activate()
    return study_case


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


# makes load step event
def make_event_EvtLod(app, events_file, load, event_parameters, event_name=None):
    # Create event
    event = events_file.CreateObject("EvtLod")
    if event_name is not None:
        event.loc_name = event_name
    else:
        event.loc_name = f"Load Event - {load.loc_name}"

    # Set load
    event.SetAttribute("p_target", load)

    # Set event parameters
    for param, value in event_parameters.items():
        event.SetAttribute(param, value)
    return event


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


# configures the ComInc and ComSim objects to run RMS simulation, then runs it
def run_RMS_simulation(
    app,
    events_file,
    results_file,
    com_inc_parameters={},
    com_sim_parameters={"tstop": 10},
):

    # configure ComInc
    com_inc = app.GetFromStudyCase("*.ComInc")
    com_inc.SetAttribute("p_event", events_file)
    com_inc.SetAttribute("p_resvar", results_file)
    for param, value in com_inc_parameters.items():
        com_inc.SetAttribute(param, value)

    # configure ComSim
    com_sim = app.GetFromStudyCase("*.ComSim")
    for param, value in com_sim_parameters.items():
        com_sim.SetAttribute(param, value)

    # Calculate initial conditions and run simulation
    com_ldf = app.GetFromStudyCase("*.ComLdf")
    if com_ldf.Execute() != 0:
        raise Exception("ComLdf failed")
    com_inc.Execute()
    com_sim.Execute()


# exports results and header files
def export_results(app, results_file, output_dir, output_name):
    # Configure ComRes
    com_res = app.GetFromStudyCase("ComRes")
    com_res.SetAttribute("pResult", results_file)
    com_res.SetAttribute("iopt_exp", 6)  # set export to csv file

    # Export header
    com_res.SetAttribute("iopt_vars", 1)  # export header
    header_path = output_dir / f"header_{output_name}.csv"
    com_res.SetAttribute("f_name", str(header_path))
    com_res.Execute()

    # Export values
    com_res.SetAttribute("iopt_vars", 0)  # export values
    results_path = output_dir / f"{output_name}.csv"
    com_res.SetAttribute("f_name", str(results_path))
    com_res.Execute()


###########################################################
# definitions
###########################################################

# elements and variables to export
export_data = {
    "ElmSym": {
        "elms": app.GetCalcRelevantObjects("*.ElmSym", 0),
        "vars": [
            "s:xmt",
            "s:P1",
            "s:Q1",
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
            "c:id",
            "c:iq",
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
            "c:Vc",
            "c:Vr",
            "s:vf",
            "s:uerrs",
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
        "vars": ["s:pt", "s:x1", "s:pt:dt", "s:x1:dt", "s:yi2"],
    },
}

# output directory
case_name = app.GetActiveProject().GetAttribute("loc_name")
package_dir = Path(__file__).parents[2]
results_dir = package_dir / "data" / "ieee39_verification"

short_circuit_bus_name = "Bus 31"
step_load_name = "Load 16"

if __name__ == "__main__":
    # configure ElmRes and IntEvt
    results_file = configure_ElmRes(
        app,
        export_data,
        f"results_short_circuit_and_load_step",
    )
    events_file = make_IntEvt(
        app,
        f"events_short_circuit_and_load_step",
    )
    # get load and bus
    load = app.GetCalcRelevantObjects(f"*{step_load_name}.ElmLod", 0)[0]
    bus = app.GetCalcRelevantObjects(f"*{short_circuit_bus_name}.ElmTerm", 0)[0]

    # make short circuit and clearance event
    make_event_short_circuit_and_clearance(app, events_file, bus, 0.1, 0.2)
    # make load event
    make_event_EvtLod(app, events_file, load, {"time": 1.5, "dP": 20, "dQ": 0})

    # run simulation
    run_RMS_simulation(
        app,
        events_file,
        results_file,
        com_inc_parameters={"iopt_adapt": 0, "dtgrd": 10},  # fixed time step of 10ms
        com_sim_parameters={"tstop": 20},
    )

    # export results
    export_results(
        app,
        results_file,
        results_dir,
        "short_circuit_and_load_step_results",
    )
