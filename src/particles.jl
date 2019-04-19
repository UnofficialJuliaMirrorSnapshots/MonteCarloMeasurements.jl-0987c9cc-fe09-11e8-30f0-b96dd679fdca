const ConcreteFloat = Union{Float64,Float32,Float16,BigFloat}
const ConcreteInt = Union{Int8,Int16,Int32,Int64,Int128,BigInt}

abstract type AbstractParticles{T,N} <: Real end
struct Particles{T,N} <: AbstractParticles{T,N}
    particles::Vector{T}
end

struct StaticParticles{T,N} <: AbstractParticles{T,N}
    particles::SArray{Tuple{N}, T, 1, N}
end

const MvParticles = Vector{<:AbstractParticles} # This can not be AbstractVector since it causes some methods below to be less specific than desired

±(μ::Real,σ) = μ + σ*Particles(DEFAUL_NUM_PARTICLES)
±(μ::AbstractVector,σ) = Particles(DEFAUL_NUM_PARTICLES, MvNormal(μ, σ))
∓(μ::Real,σ) = μ + σ*StaticParticles(DEFAUL_STATIC_NUM_PARTICLES)
∓(μ::AbstractVector,σ) = StaticParticles(DEFAUL_STATIC_NUM_PARTICLES, MvNormal(μ, σ))

"""
⊗(μ,σ) = outer_product(Normal.(μ,σ))

See also `outer_product`
"""
⊗(μ,σ) = outer_product(Normal.(μ,σ))

"""
    p = outer_product(dists::Vector{<:Distribution}, N=100_000)

Creates a multivariate systematic sample where each dimension is sampled according to the corresponding univariate distribution in `dists`. Returns `p::Vector{Particles}` where each Particles has a length approximately equal to `N`.
The particles form the outer product between `d` systematically sampled vectors with length given by the d:th root of N, where `d` is the length of `dists`, All particles will be independent and have marginal distributions given by `dists`.

See also `MonteCarloMeasurements.⊗`
"""
function outer_product(dists::AbstractVector{<:Distribution}, N=100_000)
    d = length(dists)
    N = floor(Int,N^(1/d))
    dims = map(dists) do dist
        v = systematic_sample(N,dist; permute=true)
    end
    cart_prod = vec(collect(Iterators.product(dims...)))
    p = map(1:d) do i
        Particles(getindex.(cart_prod,i))
    end
end

# StaticParticles(N::Integer = DEFAUL_NUM_PARTICLES; permute=true) = StaticParticles{Float64,N}(SVector{N,Float64}(systematic_sample(N, permute=permute)))


function print_functions_to_extend()
    excluded_functions = [fill, |>, <, display, show, promote, promote_rule, promote_type, size, length, ndims, convert, isapprox, ≈, <, (<=), (==), zeros, zero, eltype, getproperty, fieldtype, rand, randn]
    functions_to_extend = setdiff(names(Base), Symbol.(excluded_functions))
    for fs in functions_to_extend
        ff = @eval $fs
        ff isa Function || continue
        isempty(methods(ff)) && continue # Sort out intrinsics and builtins
        f = nameof(ff)
        if !isempty(methods(ff, (Real,Real)))
            println(f, ",")
        end
    end
end
function Base.show(io::IO, p::AbstractParticles{T,N}) where {T,N}
    sPT = string(typeof(p))
    if ndims(T) < 1
        print(io, "(", N, " $sPT: ", round(mean(p), digits=3), " ± ", round(std(p), digits=3),")")
    else
        print(io, "(", N, " $sPT with mean ", round.(mean(p), digits=3), " and std ", round.(sqrt.(diag(cov(p))), digits=3),")")
    end
end
for mime in (MIME"text/x-tex", MIME"text/x-latex")
    @eval function Base.show(io::IO, ::$mime, p::AbstractParticles)
        print(io, "\$")
        show(io, p)
        print("\$")
    end
end

for PT in (:Particles, :StaticParticles)
    @forward @eval($PT).particles Statistics.mean, Statistics.cov, Statistics.var, Statistics.std, Statistics.median, Statistics.quantile, Statistics.middle
    @forward @eval($PT).particles Base.iterate, Base.extrema, Base.minimum, Base.maximum

    @eval begin
        $PT(v::Vector) = $PT{eltype(v),length(v)}(v)
        $PT{T,N}(p::$PT{T,N}) where {T,N} = p
        function $PT{T,N}(n::Real) where {T,N} # This constructor is potentially dangerous, replace with convert?
            v = fill(n,N)
            $PT{T,N}(v)
        end

        function $PT(N::Integer=DEFAUL_NUM_PARTICLES, d::Distribution=Normal(0,1); permute=true, systematic=true)
            if systematic
                v = systematic_sample(N,d; permute=permute)
            else
                v = rand(d, N)
            end
            $PT{eltype(v),N}(v)
        end

        function $PT(N::Integer, d::MultivariateDistribution)
            v = rand(d,N)' |> copy # For cache locality
            map($PT{eltype(v),N}, eachcol(v))
        end
    end
    # @eval begin
    # Two-argument functions
    for ff in (+,-,*,/,//,^, max,min,minmax,mod,mod1,atan,add_sum)
        f = nameof(ff)
        @eval begin
            function (Base.$f)(p::$PT{T,N},a::Real...) where {T,N}
                $PT{T,N}(map(x->$f(x,a...), p.particles))
            end
            function (Base.$f)(a::Real,p::$PT{T,N}) where {T,N}
                $PT{T,N}(map(x->$f(a,x), p.particles))
            end
            function (Base.$f)(p1::$PT{T,N},p2::$PT{T,N}) where {T,N}
                $PT{T,N}(map($f, p1.particles, p2.particles))
            end
            function (Base.$f)(p1::$PT{T,N},p2::$PT{S,N}) where {T,S,N} # Needed for particles of different float types :/
                $PT{promote_type(T,S),N}(map($f, p1.particles, p2.particles))
            end
        end
    end
    # One-argument functions
    for ff in [*,+,-,/,
        exp,exp2,exp10,expm1,
        log,log10,log2,log1p,
        sin,cos,tan,sind,cosd,tand,sinh,cosh,tanh,
        asin,acos,atan,asind,acosd,atand,asinh,acosh,atanh,
        zero,sign,abs,sqrt,rad2deg,deg2rad]
        f = nameof(ff)
        @eval function (Base.$f)(p::$PT)
            $PT(map($f, p.particles))
        end
    end
    # end
    @eval begin

        Base.eltype(::Type{$PT{T,N}}) where {T,N} = T
        Base.promote_rule(::Type{S}, ::Type{$PT{T,N}}) where {S,T,N} = $PT{promote_type(S,T),N}
        Base.promote_rule(::Type{Complex}, ::Type{$PT{T,N}}) where {T,N} = Complex{$PT{T,N}}
        Base.promote_rule(::Type{Complex{T}}, ::Type{$PT{T,N}}) where {T<:Real,N} = Complex{$PT{T,N}}
        Base.convert(::Type{$PT{T,N}}, f::Real) where {T,N} = $PT{T,N}(fill(T(f),N))
        Base.convert(::Type{$PT{T,N}}, f::$PT{S,N}) where {T,N,S} = $PT{promote_type(T,S),N}($PT{promote_type(T,S),N}(f))
        function Base.convert(::Type{S}, p::$PT{T,N}) where {S<:ConcreteFloat,T,N}
            std(p) < 100eps(S) || throw(ArgumentError("Cannot convert a particle distribution to a float if not all particles are the same."))
            return S(p[1])
        end
        function Base.convert(::Type{S}, p::$PT{T,N}) where {S<:ConcreteInt,T,N}
            isinteger(p) || throw(ArgumentError("Cannot convert a particle distribution to an int if not all particles are the same."))
            return S(p[1])
        end
        Base.zeros(::Type{$PT{T,N}}, dim::Integer) where {T,N} = [$PT(zeros(eltype(T),N)) for d = 1:dim]
        Base.zero(::Type{$PT{T,N}}) where {T,N} = $PT(zeros(eltype(T),N))
        Base.isfinite(p::$PT{T,N}) where {T,N} = isfinite(mean(p))
        Base.round(p::$PT{T,N}, r::RoundingMode, args...; kwargs...) where {T,N} = round(mean(p), r, args...; kwargs...)
        function Base.AbstractFloat(p::$PT{T,N}) where {T,N}
            std(p) < eps(T) || throw(ArgumentError("Cannot convert a particle distribution to a number if not all particles are the same."))
            return T(p[1])
        end

        """
        union(p1::AbstractParticles, p2::AbstractParticles)

        A `Particles` containing all particles from both `p1` and `p2`. Note, this will be twice as long as `p1` or `p2` and thus of a different type.
        `pu = Particles([p1.particles; p2.particles])`
        """
        function Base.union(p1::$PT{T,NT},p2::$PT{T,NS}) where {T,NT,NS}
            $PT([p1.particles; p2.particles])
        end

        """
        intersect(p1::AbstractParticles, p2::AbstractParticles)

        A `Particles` containing all particles from the common support of `p1` and `p2`. Note, this will be of undetermined length and thus undetermined type.
        """
        function Base.intersect(p1::$PT,p2::$PT)
            mi = max(minimum(p1),minimum(p2))
            ma = min(maximum(p1),maximum(p2))
            f = x-> mi <= x <= ma
            $PT([filter(f, p1.particles); filter(f, p2.particles)])
        end

        Base.:^(p::$PT, i::Integer) = $PT(p.particles.^i) # Resolves ambiguity
        Base.:\(p::Vector{<:$PT}, p2::Vector{<:$PT}) = Matrix(p)\Matrix(p2) # Must be here to be most specific
    end


end

Base.length(p::AbstractParticles{T,N}) where {T,N} = N
Base.ndims(p::AbstractParticles{T,N}) where {T,N} = ndims(T)
Base.:\(H::MvParticles,p::AbstractParticles) = Matrix(H)\p.particles
# Base.:\(p::AbstractParticles, H) = p.particles\H
# Base.:\(p::MvParticles, H) = Matrix(p)\H
# Base.:\(H,p::MvParticles) = H\Matrix(p)

Base.Broadcast.broadcastable(p::Particles) = Ref(p)
Base.getindex(p::AbstractParticles, i::Integer) = getindex(p.particles, i)
Base.getindex(v::MvParticles, i::Int, j::Int) = v[j][i]

Base.Matrix(v::MvParticles) = reduce(hcat, getfield.(v,:particles))
Statistics.mean(v::MvParticles) = mean.(v)
Statistics.cov(v::MvParticles,args...;kwargs...) = cov(Matrix(v), args...; kwargs...)
# function Statistics.var(v::MvParticles,args...;kwargs...) # Not sure if it's a good idea to define this. Is needed for when var(v::AbstractArray) is used
#     s2 = map(1:length(v[1])) do i
#         var(getindex.(v,i))
#     end
#     eltype(v)(s2)
# end
meanstd(p::AbstractParticles) = std(p)/sqrt(length(p))
meanvar(p::AbstractParticles) = var(p)/length(p)

Distributions.Normal(p::AbstractParticles) = Normal(mean(p), std(p))
Distributions.MvNormal(p::AbstractParticles) = MvNormal(mean(p), cov(p))
Distributions.MvNormal(p::MvParticles) = MvNormal(mean(p), cov(p))
Distributions.fit(d::Type{<:MultivariateDistribution}, p::MvParticles) = fit(d,Matrix(p)')
Distributions.fit(d::Type{<:Distribution}, p::AbstractParticles) = fit(d,p.particles)

Base.:(==)(p1::AbstractParticles{T,N},p2::AbstractParticles{T,N}) where {T,N} = p1.particles == p2.particles
Base.:(!=)(p1::AbstractParticles{T,N},p2::AbstractParticles{T,N}) where {T,N} = p1.particles != p2.particles
Base.:<(a::Real,p::AbstractParticles) = a < mean(p)
Base.:<(p::AbstractParticles,a::Real) = mean(p) < a
Base.:<(p::AbstractParticles, a::AbstractParticles, lim=2) = mean(p) < mean(a)
Base.:(<=)(p::AbstractParticles{T,N}, a::AbstractParticles{T,N}, lim::Real=2) where {T,N} = mean(p) <= mean(a)

Base.:≈(a::Real,p::AbstractParticles, lim=2) = abs(mean(p)-a)/std(p) < lim
Base.:≈(p::AbstractParticles, a::Real, lim=2) = abs(mean(p)-a)/std(p) < lim
Base.:≈(p::AbstractParticles, a::AbstractParticles, lim=2) = abs(mean(p)-mean(a))/(2sqrt(std(p)^2 + std(a)^2)) < lim
Base.:≉(a,b::AbstractParticles,lim=2) = !(≈(a,b,lim))
Base.:≉(a::AbstractParticles,b,lim=2) = !(≈(a,b,lim))
Base.:≉(a::AbstractParticles,b::AbstractParticles,lim=2) = !(≈(a,b,lim))


Base.:!(p::AbstractParticles) = all(p.particles .== 0)

Base.isinteger(p::AbstractParticles) = all(isinteger, p.particles)
Base.iszero(p::AbstractParticles) = all(iszero, p.particles)


≲(a::Real,p::AbstractParticles,lim=2) = (mean(p)-a)/std(p) > lim
≲(p::AbstractParticles,a::Real,lim=2) = (a-mean(p))/std(p) > lim
≲(p::AbstractParticles,a::AbstractParticles,lim=2) = (mean(p)-mean(a))/(2sqrt(std(p)^2 + std(a)^2)) > lim
≳(a::Real,p::AbstractParticles,lim=2) = ≲(p,a,lim)
≳(p::AbstractParticles,a::Real,lim=2) = ≲(a,p,lim)
≳(p::AbstractParticles,a::AbstractParticles,lim=2) = ≲(a,p,lim)
Base.eps(p::Type{<:AbstractParticles{T,N}}) where {T,N} = eps(T)
Base.eps(p::AbstractParticles{T,N}) where {T,N} = eps(T)

function LinearAlgebra.norm(x::AbstractParticles, p::Union{AbstractFloat, Integer}=2)
    if p == 2
        return abs(mean(x))
    elseif p == Inf
        return max(extrema(x)...)
    end
    throw(ArgumentError("Cannot take $(p)-norm of particles"))
end

"""
ℂ2ℂ_function(f::Function, z::Complex{<:AbstractParticles})
applies `f : ℂ → ℂ ` to `z::Complex{<:AbstractParticles}`.
"""
function ℂ2ℂ_function(f::F, z::Complex{T}) where {F,T<:AbstractParticles}
    rz,iz = z.re,z.im
    s = map(1:length(rz.particles)) do i
        f(complex(rz[i], iz[i]))
    end
    complex(T(real.(s)), T(imag.(s)))
end


Base.sqrt(z::Complex{<: AbstractParticles}) = ℂ2ℂ_function(sqrt, z)

"""
    ℝⁿ2ℝⁿ_function(f::Function, p::AbstractArray{T})
Applies  `f : ℝⁿ → ℝⁿ` to an array of particles.
"""
function ℝⁿ2ℝⁿ_function(f::F, p::AbstractArray{T}) where {F,T<:AbstractParticles}
    individuals = map(1:length(p[1])) do i
        f(getindex.(p,i))
    end
    out = similar(p)
    map(1:length(p)) do i
        out[i] = T(getindex.(individuals,i))
    end
    reshape(out, size(p))
end


Base.exp(p::AbstractMatrix{<:AbstractParticles}) = ℝⁿ2ℝⁿ_function(exp, p)