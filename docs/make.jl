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
        "Home" => "index.md",
    ],
)
