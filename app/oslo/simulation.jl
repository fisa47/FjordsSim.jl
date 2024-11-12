# Copyright 2024 The FjordsSim Authors.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

using Printf
using FileIO
using JLD2

include("setup.jl")

using .FjordsSim: progress, coupled_hydrostatic_simulation

## Model Setup
sim_setup = setup_region()

coupled_simulation = coupled_hydrostatic_simulation(sim_setup)

## Callbacks
coupled_simulation.callbacks[:progress] = Callback(progress, IterationInterval(100))

## Set up output writers
ocean_sim = coupled_simulation.model.ocean
ocean_model = ocean_sim.model
surface_prefix = joinpath(homedir(), "FjordsSim_results", "oslo", "oslo_surface_snapshots")
ocean_sim.output_writers[:surface] = JLD2OutputWriter(
    ocean_model, merge(ocean_model.tracers, ocean_model.velocities);
    schedule = TimeInterval(1hour),
    filename = "$surface_prefix.jld2",
    indices=(:, :, grid[].Nz),
    overwrite_existing = true,
    array_type=Array{Float32}
)

profile_prefix = joinpath(homedir(), "FjordsSim_results", "oslo", "oslo_snapshots")
ocean_sim.output_writers[:profile] = JLD2OutputWriter(
    ocean_model, merge(ocean_model.tracers, ocean_model.velocities);
    schedule = TimeInterval(1day),
    filename = "$profile_prefix.jld2",
    overwrite_existing = true,
    array_type=Array{Float32}
)

## Spinning up the simulation
# We use an adaptive time step that maintains the [CFL condition](https://en.wikipedia.org/wiki/Courant%E2%80%93Friedrichs%E2%80%93Lewy_condition) equal to 0.1.
ocean_sim.stop_time = 10days
coupled_simulation.stop_time = 10days
conjure_time_step_wizard!(ocean_sim; cfl=0.1, max_Δt=1.5minutes, max_change=1.01)
run!(coupled_simulation)

## Running the simulation
# This time, we set the CFL in the time_step_wizard to be 0.25 as this is the maximum recommended CFL to be
# used in conjunction with Oceananigans' hydrostatic time-stepping algorithm ([two step Adams-Bashfort](https://en.wikipedia.org/wiki/Linear_multistep_method))
ocean_sim.stop_time = 355days
coupled_simulation.stop_time = 355days
conjure_time_step_wizard!(ocean_sim; cfl=0.25, max_Δt=10minutes, max_change=1.01)
run!(coupled_simulation)
