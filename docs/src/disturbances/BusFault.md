```@meta
CurrentModule = RMSPowerSims
```
# BusFault

Implements a three-phase short-circuit at a bus with zero fault resistance. Note that the `BusFault` disturbance requires the definition of a `ComponentModel` type to model the faulted bus. The `BusFaultModel` replaces the `NodeModel` during the fault.

```@docs
BusFault
```
```@docs
perturb_model!(::PowerSystemModel, ::BusFault)
```

#### BusFaultModel
```@docs
BusFaultModel
```
```@docs
update!(Any,Any,Any,::BusFaultModel,Any)
```