module MonteCarloMeasurements

const DEFAUL_NUM_PARTICLES = 500
const DEFAUL_STATIC_NUM_PARTICLES = 100

export AbstractParticles,Particles,StaticParticles, WeightedParticles, sigmapoints, transform_moments, ≲,≳, systematic_sample, outer_product, meanstd, meanvar, register_primitive, register_primitive_multi, register_primitive_single, ℝⁿ2ℝⁿ_function, ℂ2ℂ_function, resample!, @bymap, @bypmap
# Plot exports
export errorbarplot, mcplot, ribbonplot

# Statistics reexport
export mean, std, cov, var, quantile, median
# Distributions reexport
export Normal, MvNormal, Cauchy, Beta, Exponential, Gamma, Laplace, Uniform, fit, logpdf


import Base: add_sum


using LinearAlgebra, Statistics, Random, StaticArrays, RecipesBase, GenericLinearAlgebra, MacroTools
using Distributed: pmap
import StatsBase: ProbabilityWeights
using Lazy: @forward

using Distributions, StatsBase

include("types.jl")
include("register_primitive.jl")
include("sampling.jl")
include("particles.jl")
include("sigmapoints.jl")
include("resampling.jl")
include("bymap.jl")
include("diff.jl")
include("plotting.jl")
include("optimize.jl")

end


# TODO: Mutation, test on ControlSystems
# TODO: ifelse?
