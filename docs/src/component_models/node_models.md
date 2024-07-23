```@meta
CurrentModule = RMSPowerSims
```
# NodeModel

### Subtypes
Subtypes have been defined indicating whether a node has any generators or loads connected. This reduces the number of conditional statements required during simulation.

```@docs
GenConnected
```
```@docs
LoadConnected
```
```@docs
NoGen
```
```@docs
HasGen
```
```@docs
NoLoad
```
```@docs
HasLoad
```

### NodeModel

Implementation of each node model uses a reduced admittance matrix which only contains the elements relevant to calculation (connected branches).

```@docs
NodeModel
```

To avoid repetition, only the equations for `NodeModel{HasGen,HasLoad}` are presented. The equations of the other generator/load combinations are the same but with the `Pg` and `Qg` terms omitted where no generators are connected, and the `Pd` and `Qd` terms omitted where no loads are connected.

```@docs
update!(Any,Any,Any,::NodeModel{HasGen,HasLoad},Any)
```

# Calculation of Initial Conditions

The initial conditions for `V` and `θ` are taken from the load flow solution.