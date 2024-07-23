```@meta
CurrentModule = RMSPowerSims
```

# Data Structures
RMSPowerSims.jl uses two high-level data structures:

- The PowerModels.jl network data dictionary stores all network data, modeling details of components, simulation settings, and time series results. 

- The PowerSystemSimulation object stores the data that is passed to the differential equation solver. 

RMSPowerSims has been designed so that a user who simply wants to perform simulations using existing component models will predominantly be able to access the network data dictionary. The only time it should be necessary to interact with the PowerSystemSimulation object is to add disturbances.

The additional dynamic simulation data for a generator or load is specified within the network data dictionary, as a Dict in the form

    "dynamic_model" => Dict{String,Any}(
        "model_type" => model_type::ComponentModel,
        "parameters" => Dict{String,Any}(),
        ),

In the case of generators, an additional entry is included for controllers. Controller data is entered in the same form as above.

The custom data structures used in the package are outlined below.

# PowerSystemSimulation
```@docs
    PowerSystemSimulation
```

# PowerSystemModel
```@docs
    PowerSystemModel
```

# ComponentModelData
```@docs
    ComponentModelData
```
