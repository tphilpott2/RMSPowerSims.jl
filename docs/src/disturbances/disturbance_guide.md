```@meta
CurrentModule = RMSPowerSims
```
# Disturbance Guide

All disturbances are implemented as a subtype of the abstract type `Disturbance`. An instance of a `Disturbance` should include all the parameters required for the disturbances implementation. The fields of a `Disturbance` subtype are flexible but must include
-`t_disturbance`::Float64: The time that the disturbance occurs (s)
-`restart_simulation`::Bool: Boolean indication the simulation should be restarted at the time of the disturbance.

Disturbances are applied to the `PowerSystemModel` using the `perturb_model!` function. Multiple dispatch is used to determine the specific method of `perturb_model!` that should be called.

```@docs
perturb_model!
```
Note: the docstring above is generated using an argumentless definition of the function that should not be called. For details of a specific method consult the file relating to the disturbance.

#### Callbacks

If the disturbance is set to happen during the simulation (`restart_simulation` = false) a callback is generated and passed to the solver.

```@docs
create_callback
```