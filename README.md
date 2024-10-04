# RMSPowerSims

[![Build Status](https://github.com/tphilpott2/RMSPowerSims.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/tphilpott2/RMSPowerSims.jl/actions/workflows/CI.yml?query=branch%3Amaster)

**RMSPowerSims** is a Julia package designed for phasor-based simulation of electric power systems. It extends the PowerModels.jl Network Data Dictionary (NDD) structure to support the modelling and simulation of system dynamics, offering a user-friendly and flexible approach rather than focusing solely on peak performance. It allows users to build custom models for components such as generators, control systems, loads, and disturbances, while also providing a set of predefined models.

For visualization, the package includes various plotting functions, based on `Plots.jl`, making it easy to generate and interpret simulation results.

## Features
- Extention of the PowerModels.jl NDD structure for dynamic system modelling.
- Interface with the `DifferentialEquations.jl` package for solving power system differential equations.
- Customizable models for generators, loads, control systems, and disturbances.
- Predefined models for common components and disturbances.
- Visualization tools using `Plots.jl` for results analysis.

## Installation

To install RMSPowerSims, follow these steps:

1. Clone the repository and add it to your Julia environment:
   ```julia
   ] develop https://github.com/tphilpott2/RMSPowerSims.jl

2. Install the required dependencies, such as PowerModels, Sundials, and DifferentialEquations:
   ```julia
   ] add PowerModels Sundials DifferentialEquations

3. Ensure that your Julia registry is up to date by running:
   ```julia
   ] update

## Contributing

We welcome contributions! If you find a bug, have ideas for improvements, or have developed new component models that you wish to provide, feel free to open an issue or submit a pull request.

## Citation

Please use the following if citing RMSPowerSims.jl:

   ```bibtex
 @article{Philpott2024,
   author    = {Philpott, T. and Agalgaonkar, A. P. and Brinsmead, T. and Muttaqi, K. M.},
   title     = {An Open-Source Julia Package for RMS Time-Domain Simulations of Power Systems},
   journal   = {Preprints},
   year      = {2024},
   volume    = {2024092243},
   doi       = {10.20944/preprints202409.2243.v1},
   url       = {https://doi.org/10.20944/preprints202409.2243.v1}
 }
