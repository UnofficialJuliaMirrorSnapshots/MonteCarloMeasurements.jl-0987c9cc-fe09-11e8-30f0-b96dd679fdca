using MonteCarloMeasurements
using Test, LinearAlgebra, Statistics, Random
import MonteCarloMeasurements: ±, ∓, ⊗, gradient, optimize
import Plots

Random.seed!(0)

@testset "MonteCarloMeasurements.jl" begin

    # σ/√N = σm
    @testset "sampling" begin
        for _ = 1:10
            @test -3 < mean(systematic_sample(100))*sqrt(100) < 3
            @test -3 < mean(systematic_sample(10000))*sqrt(10000) < 3
            @test -0.9 < std(systematic_sample(100)) < 1.1
            @test -0.9 < std(systematic_sample(10000)) < 1.1
        end
        @test systematic_sample(10000, Normal(1,1)) |> Base.Fix1(fit, Normal) |> params |> x-> all(isapprox.(x,(1,1), atol=0.1))
        systematic_sample(10000, Gamma(1,1)) #|> Base.Fix1(fit, Gamma)
        systematic_sample(10000, TDist(1)) #|> Base.Fix1(fit, TDist)
        @test systematic_sample(10000, Beta(1,1)) |> Base.Fix1(fit, Beta) |> params |> x-> all(isapprox.(x,(1,1), atol=0.1))

    end
    @testset "Particles" begin
        for PT = (Particles, StaticParticles)

            p = PT(1000)
            @test 0 ± 1 ≈ p
            @test 0 ∓ 1 ≈ p
            @test 0 ∓ 1 isa StaticParticles
            @test sum(p) ≈ 0
            @test cov(p) ≈ 1 atol=0.2
            @test std(p) ≈ 1 atol=0.2
            @test var(p) ≈ 1 atol=0.2
            @test meanvar(p) ≈ 1/(length(p)) rtol=5e-3
            @test meanstd(p) ≈ 1/sqrt(length(p)) rtol=5e-3
            @test p <= p
            @test p >= p
            @test !(p < p)
            @test !(p > p)
            @test (p < 1+p)
            @test (p+1 > p)
            @test !(p ≲ p)
            @test !(p ≳ p)
            @test (p ≲ 2.1)
            @test !(p ≲ 1.9)
            @test (p ≳ -2.1)
            @test !(p ≳ -1.9)
            @test (-2.1 ≲ p)
            @test !(-1.9 ≲ p)
            @test (2.1 ≳ p)
            @test !(1.9 ≳ p)
            @test p ≈ p
            @test p ≈ 0
            @test 0 ≈ p
            @test p != 0
            @test p != 2p
            @test p ≈ 1.9std(p)
            @test !(p ≈ 2.1std(p))
            @test p ≉ 2.1std(p)
            @test !(p ≉ 1.9std(p))


            f = x -> 2x + 10
            @test 9.6 < mean(f(p)) < 10.4
            @test 9.6 < f(p) < 10.4
            @test f(p) ≈ 10
            @test !(f(p) ≲ 11)
            @test f(p) ≲ 15
            @test 5 ≲ f(p)
            @test Normal(f(p)).μ ≈ mean(f(p))
            @test fit(Normal, f(p)).μ ≈ mean(f(p))

            f = x -> x^2
            p = PT(1000)
            @test 0.9 < mean(f(p)) < 1.1
            @test 0.9 < mean(f(p)) < 1.1
            @test f(p) ≈ 1
            @test !(f(p) ≲ 1)
            @test f(p) ≲ 4
            @test -2.2 ≲ f(p)
            @test MvNormal([f(p),p]) isa MvNormal

            A = randn(3,3) .+ [PT(100) for i = 1:3, j = 1:3]
            a = [PT(100) for i = 1:3]
            b = [PT(100) for i = 1:3]
            @test sum(a.*b) ≈ 0
            @test all(A*b .≈ [0,0,0])

            @test all(A\b .≈ zeros(3))
            @test_nowarn qr(A)
            @test_nowarn Particles(100, MvNormal(2,1)) ./ Particles(100, Normal(2,1))
        end
    end



    @testset "Multivariate Particles" begin
        for PT = (Particles, StaticParticles)

            p = PT(1000, MvNormal(2,1))
            @test_nowarn sum(p)
            @test cov(p) ≈ I atol=0.2
            @test mean(p) ≈ [0,0] atol=0.2
            @test size(Matrix(p)) == (1000,2)

            p = PT(100, MvNormal(2,2))
            @test cov(p) ≈ 4I atol=2
            @test mean(p) ≈ [0,0] atol=1
            @test size(Matrix(p)) == (100,2)

            p = PT(1000, MvNormal(2,2))
            @test fit(MvNormal, p).μ ≈ mean(p)
            @test MvNormal(p).μ ≈ mean(p)
            @test cov(MvNormal(p)) ≈ cov(p)
        end
    end
    @testset "gradient" begin
        e = 0.001
        p = 3 ± e
        f = x -> x^2
        fp = f(p)
        @test gradient(f,p)[1] ≈ 6 atol=1e-4
        @test gradient(f,p)[2] ≈ 2e atol=1e-4
        # @test gradient(f,3) > 6 # Convex function
        @test gradient(f,3) ≈ 6

        A = randn(3,3)
        H = A'A
        h = randn(3)
        c = randn()
        @assert isposdef(H)
        f = x -> (x'H*x + h'x) + c
        j = x -> H*x + h

        e = 0.001
        x = randn(3)
        xp = x ± e
        g = 2H*x + h
        @test MonteCarloMeasurements.gradient(f,xp) ≈ g atol = 0.1
        @test MonteCarloMeasurements.jacobian(j,xp) ≈ H
    end
    @testset "leastsquares" begin
        n, m = 10000, 3
        A = randn(n,m)
        x = randn(m)
        y = A*x
        σ = 0.1
        yn = y .+ σ.*randn()
        # xh = A\y
        C1 = σ^2*inv(A'A)

        yp = y .+ σ.*Particles.(2000)
        xhp = (A'A)\A'yp
        @test sum(abs, tr((cov(xhp) .- C1) ./ abs.(C1))) < 0.2

        @test norm(cov(xhp) .- C1) < 1e-7
    end

    @testset "misc" begin
        p = 0 ± 1
        @test p[1] == p.particles[1]
        @test_nowarn display(p)
        @test_nowarn show(p)
        @test_nowarn show(stdout, MIME"text/x-latex"(), p)
        @test Particles{Float64,500}(p) == p
        @test Particles{Float64,5}(0) == 0*Particles(5)
        @test length(Particles(100, MvNormal(2,1))) == 2
        @test length(p) == 500
        @test ndims(p) == 0
        @test eltype(typeof(p)) == Float64
        @test eltype(p) == Float64
        @test convert(Int, 0p) == 0
        @test promote_type(Particles{Float64,10}, Float64) == Particles{Float64,10}
        @test promote_type(Particles{Float64,10}, Int64) == Particles{Float64,10}
        @test promote_type(Particles{Float64,10}, ComplexF64) == Complex{Particles{Float64,10}}
        @test promote_type(Particles{Float64,10}, ComplexF64) == Complex{Particles{Float64,10}}
        @test convert(Float64, 0p) isa Float64
        @test convert(Float64, 0p) == 0
        @test convert(Int, 0p) isa Int
        @test convert(Int, 0p) == 0
        @test_throws ArgumentError convert(Int, p)
        @test_throws ArgumentError AbstractFloat(p)
        @test AbstractFloat(0p) == 0.0
        @test Particles(500) + Particles(randn(Float32, 500)) isa typeof(Particles(500))
        @test_nowarn sqrt(complex(p,p)) == 1
        @test isfinite(p)
        @test iszero(0p)
        @test !iszero(p)
        @test !(!p)
        @test !(0p)
        @test round(p) ≈ 0 atol=0.1
        @test norm(0p) == 0
        @test norm(p) ≈ 0 atol=0.01
        @test norm(p,Inf) > 0
        @test_throws ArgumentError norm(p,1)
        @test MvNormal(Particles(500, MvNormal(2,1))) isa MvNormal
        @test eps(typeof(p)) == eps(Float64)
        @test eps(p) == eps(Float64)
        A = randn(2,2)
        B = A .± 0
        @test sum(abs, exp(A) .- exp(B)) < 1e-9

        @test intersect(p,p) == union(p,p)
        @test length(intersect(p, 1+p)) < 2length(p)
        @test length(union(p, 1+p)) == 2length(p)
    end

    @testset "mutation" begin
        function adder!(x)
            for i = eachindex(x)
                x[i] += 1
            end
            x
        end
        x = (1:5) .± 1
        adder!(x)
        @test all(x .≈ (2:6) .± 1)
    end

    @testset "outer_product" begin
        d = 2
        μ = zeros(d)
        σ = ones(d)
        p = μ ⊗ σ
        @test length(p) == 2
        @test length(p[1]) <= 100_000
        @test cov(p) ≈ I atol=1e-1
        p = μ ⊗ 1
        @test length(p) == 2
        @test length(p[1]) <= 100_000
        @test cov(p) ≈ I atol=1e-1
        p = 0 ⊗ σ
        @test length(p) == 2
        @test length(p[1]) <= 100_000
        @test cov(p) ≈ I atol=1e-1
    end

    @testset "plotting" begin
        p = 0 ± 1
        v = [p,p]
        @test_nowarn Plots.plot(p)
        @test_nowarn Plots.plot(v)
        @test_nowarn Plots.plot(x->x^2,v)
        @test_nowarn Plots.plot(v,v)
        @test_nowarn Plots.plot(v,ones(2))
        @test_nowarn Plots.plot(1:2,v)

        @test_nowarn errorbarplot(1:2,v)
        @test_nowarn mcplot(1:2,v)
        @test_nowarn ribbonplot(1:2,v)

        @test_nowarn MonteCarloMeasurements.print_functions_to_extend()
    end

    @testset "optimize" begin
        function rosenbrock2d(x)
            return (1.0 - x[1])^2 + 100.0 * (x[2] - x[1]^2)^2
        end
        @test any(1:10) do i
            p = -1ones(2) .+ 2 .*Particles.(200) # Optimum is in [1,1]
            popt = optimize(rosenbrock2d, deepcopy(p))
            all(popt .≈ [1,1])
        end
    end
end



# Integration tests and bechmarks

# using BenchmarkTools
# A = [StaticParticles(100) for i = 1:3, j = 1:3]
# B = similar(A, Float64)
# @btime qr($(copy(A)))
# @btime map(_->qr($B), 1:100);

#
# # Benchmark and comparison to Measurements.jl
# using BenchmarkTools, Printf, ControlSystems
# using MonteCarloMeasurements, Measurements
# using Measurements: ±
# using MonteCarloMeasurements: ∓
# w = exp10.(LinRange(-0.7,0.3,50))
#
# p = 1 ± 0.1
# ζ = 0.3 ± 0.1
# ω = 1 ± 0.1
# Gm = tf([p*ω], [1, 2ζ*ω, ω^2])
# # tm = @belapsed bode($Gm,$w)
#
# p = 1 ∓ 0.1
# ζ = 0.3 ∓ 0.1
# ω = 1 ∓ 0.1
# Gmm = tf([p*ω], [1, 2ζ*ω, ω^2])
# # tmm = @belapsed bode($Gmm,$w)
#
# σquant = 1-(cdf(Normal(0,1), 1)-cdf(Normal(0,1), -1))
#
# magm = bode(Gm,w)[1][:]
# magmm = bode(Gmm,w)[1][:]
# errorbarplot(w,magmm, σquant/2, xscale=:log10, yscale=:log10, lab="Particles", linewidth=2)
# plot!(w,magm, lab="Measurements")
