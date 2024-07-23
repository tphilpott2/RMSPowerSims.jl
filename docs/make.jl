using RMSPowerSims
using Documenter

DocMeta.setdocmeta!(RMSPowerSims, :DocTestSetup, :(using RMSPowerSims); recursive=true)

makedocs(;
    modules=[RMSPowerSims],
    authors="tom philpott <tsp266@uowmail.edu.au> and contributors",
    sitename="RMSPowerSims.jl",
    format=Documenter.HTML(;
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Tutorial" => "tutorial.md",
        "Data Structures" => "data_structures.md",
        "Component Models" => [
            "Component Model Guide" => "component_models\\component_model_guide.md",
            "Generators" => [
                "component_models\\generator_models\\SixthOrderModel.md",
            ],
            "Controllers" => [
                "component_models\\controller_models\\IEEET1.md"
            ],
            "Loads" => [
                "component_models\\load_models\\ZIPLoad.md"
            ],
            "Nodes" => "component_models\\node_models.md",
            "Other" => "component_models\\other_models.md",
        ],
        "Disturbances" => [
            "Disturbance Guide" => "disturbances\\disturbance_guide.md",
            "Bus Fault" => "disturbances\\BusFault.md",
            "Clear Bus Fault" => "disturbances\\ClearBusFault.md",
            "Load Step" => "disturbances\\LoadStep.md",
        ],
        "Network IO" => "network_io.md",
        "Reference" => "reference.md",
    ],
)
