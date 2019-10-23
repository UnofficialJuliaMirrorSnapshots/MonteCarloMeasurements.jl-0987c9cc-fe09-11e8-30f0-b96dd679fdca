using Documenter, MonteCarloMeasurements

makedocs(sitename="MonteCarloMeasurements Documentation", doctest = false, modules=[MonteCarloMeasurements]) # Due to lots of plots, this will just have to be run on my local machine

deploydocs(
    deps   = Deps.pip("pygments", "mkdocs", "python-markdown-math", "mkdocs-cinder"),
    repo = "github.com/baggepinnen/MonteCarloMeasurements.jl.git"
)
