
@recipe function plot(p::AbstractParticles)
    seriestype --> :histogram
    @series p.particles
end

# @recipe f(::Type{<:AbstractParticles}, p::AbstractParticles) = p.particles # Does not seem to be needed

function handle_args(p)
    length(p.args) < 2 && throw(ArgumentError("This function is called with at least two arguments (x, y, ..."))
    x,y = p.args[1:2]
    y isa AbstractArray{<:AbstractParticles} || throw(ArgumentError("The second argument must be a vector of some kind of Particles"))
    x,y
end
@userplot Errorbarplot
@recipe function plt(p::Errorbarplot)
    x,y = handle_args(p)
    q = length(p.args) >= 3 ? p.args[3] : 0.025
    m = mean.(y)
    lower = -(quantile.(y,q)-m)
    upper = quantile.(y,1-q)-m
    label --> "Mean with $q quantile"
    yerror := (lower,upper)
    x,m
end

@userplot MCplot
@recipe function plt(p::MCplot)
    x,y = handle_args(p)
    label --> ""
    alpha --> 0.5
    m = Matrix(y)'
    x,m
end

@userplot Ribbonplot
@recipe function plt(p::Ribbonplot)
    x,y = handle_args(p)
    q = length(p.args) >= 3 ? p.args[3] : 2.
    label --> "Mean ± $q stds"
    m = mean.(y)
    ribbon := q*std.(y)
    x,m
end

"""
errorbarplot(x,y,[q=0.05])

Plots a vector of particles with error bars at quantile `q`
"""
errorbarplot

"""
mcplot(x,y,[q=0.025])

Plots all trajectories represented by a vector of particles
"""
mcplot

"""
ribbonplot(x,y,[q=2])

Plots a vector of particles with a ribbon representing `q*std(y)`. Default width is 2σ
"""
ribbonplot



@recipe function plt(y::MvParticles, q=2)
    ribbon := q.*std.(y)
    mean.(y)
end

@recipe function plt(func::Function, x::MvParticles)
    y = func.(x)
    xerror := std.(x)
    yerror := std.(y)
    mean.(x), mean.(y)
end

@recipe function plt(x::MvParticles, y::MvParticles, q=0.025; points=false)
    my = mean.(y)
    mx = mean.(x)
    if points
        @series begin
            seriestype --> :scatter
            primary := false
            alpha --> 0.1
            Matrix(x), Matrix(y)
        end
    else
        lowery = -(quantile.(y,q)-my)
        uppery = quantile.(y,1-q)-my
        lowerx = -(quantile.(x,q)-mx)
        upperx = quantile.(x,1-q)-mx
        yerror := (lowery,uppery)
        xerror := (lowerx,upperx)
        label --> "Mean with $q quantile"
    end
    mean.(x), mean.(y)
end

@recipe function plt(x::MvParticles, y::AbstractArray)
    xerror := std.(x)
    mean.(x), y
end

@recipe function plt(x::AbstractArray, y::MvParticles, q=2)
    ribbon := q.*std.(y)
    label --> "Mean ± $q stds"
    x, mean.(y)
end
