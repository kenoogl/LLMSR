using CSV
using DataFrames
using Statistics
using BlackBoxOptim
using Plots
using JSON3
using Dates

# Include necessary modules
include("src/Phase5.jl")
using .Phase5

# --- Model Definitions ---

# 1. Jensen Model (Top-hat)
function jensen_wake(x, r, Ct, D, k)
    # x: downstream distance
    # r: radial distance
    # Ct: thrust coefficient (assumed constant or derived)
    # D: rotor diameter
    # k: wake decay constant
    
    # Initial diameter
    D0 = D * sqrt((1 + sqrt(1 - Ct)) / (2 * sqrt(1 - Ct))) # Betz approximation for initial expansion
    # Or simpler: D0 = D
    
    # Wake diameter at x
    Dw = D + 2 * k * x
    
    # Velocity deficit
    # u/u0 = 1 - (1 - sqrt(1-Ct)) * (D/Dw)^2
    # But we are fitting coefficients, so we can use a simplified form:
    # deficit = a * (D / (D + 2*k*x))^2
    
    # Condition: inside wake
    if r <= Dw / 2
        return (1 - sqrt(1 - Ct)) * (D / Dw)^2
    else
        return 0.0
    end
end

# 2. Bastankhah-Porté-Agel Model (Gaussian)
function bastankhah_wake(x, r, Ct, D, k_star)
    # sigma = k*x + epsilon*D
    # We simplify to sigma/D = k*x/D + epsilon
    
    # Normalized coordinates
    x_D = x / D
    r_D = r / D
    
    # Sigma (width)
    # Typical epsilon is around 0.2 * sqrt(beta)
    beta = 0.5 * (1 + sqrt(1 - Ct))
    epsilon = 0.2 * sqrt(beta) 
    
    sigma_D = k_star * x_D + epsilon
    
    # Amplitude
    C = 1 - sqrt(1 - (Ct / (8 * sigma_D^2)))
    
    return C * exp(-0.5 * (r_D / sigma_D)^2)
end

# 3. LLM Best Model (Gen 20)
function llm_best_model(x, r, nut, coeffs)
    a, b, c, d, e, f, g = coeffs
    # Formula: a * exp(-b*x) * exp(-c*r^2) * (1 + d*tanh(e*nut) * exp(-0.1*x) * (1 + f*abs(r)))^(-1.2) + g
    
    # Note: The formula string in JSON might use 'x' and 'r' which are normalized in the evaluator.
    # Here we assume inputs x, r are already normalized if the coefficients were trained on normalized data.
    # Based on Phase5.jl, inputs are normalized.
    
    term1 = a * exp(-b * x) * exp(-c * r^2)
    term2 = (1 + d * tanh(e * nut) * exp(-0.1 * x) * (1 + f * abs(r)))^(-1.2)
    
    return term1 * term2 + g
end

# --- Optimization Wrapper ---

function optimize_jensen(df)
    # Optimize k (decay constant)
    # Ct is usually around 0.8 for these cases, or we can optimize it too.
    # Let's optimize k and assume Ct=0.8 for simplicity, or optimize both 'a' (amplitude factor) and 'k'.
    # Standard Jensen: deficit = (1-sqrt(1-Ct)) * (1 / (1 + 2*k*x/D))^2
    # Let's optimize 'A' and 'k' in: A * (1 / (1 + k*x))^2  (assuming x is normalized x/D)
    
    function loss(params)
        A, k = params
        mse = 0.0
        for row in eachrow(df)
            x = row.x_D
            r = row.r_D
            target = row.u_def
            
            # Jensen radius
            Rw = 0.5 + k * x
            
            pred = 0.0
            if abs(r) <= Rw
                pred = A * (0.5 / Rw)^2 # D=1 in normalized space
            end
            
            mse += (pred - target)^2
        end
        return mse / nrow(df)
    end
    
    res = bboptimize(loss; SearchRange = [(0.0, 2.0), (0.0, 0.5)], NumDimensions = 2, MaxTime = 10.0, TraceMode=:silent)
    return best_candidate(res), best_fitness(res)
end

function optimize_bastankhah(df)
    # Optimize A (amplitude related to Ct) and k (growth rate)
    # Pred = A * (sigma)^(-2) * exp(...) ? 
    # Standard: (1-sqrt(1-Ct/(8*sigma^2))) ... approx A / sigma^2
    # Let's use the simplified Gaussian form often used in fitting:
    # A * exp(-r^2 / (2*sigma^2)) / sigma^2
    # where sigma = k*x + epsilon
    
    function loss(params)
        A, k, epsilon = params
        mse = 0.0
        for row in eachrow(df)
            x = row.x_D
            r = row.r_D
            target = row.u_def
            
            sigma = k * x + epsilon
            pred = (A / sigma^2) * exp(-0.5 * (r / sigma)^2)
            
            mse += (pred - target)^2
        end
        return mse / nrow(df)
    end
    
    res = bboptimize(loss; SearchRange = [(0.0, 1.0), (0.0, 0.2), (0.0, 0.5)], NumDimensions = 3, MaxTime = 10.0, TraceMode=:silent)
    return best_candidate(res), best_fitness(res)
end

# --- Main Benchmarking Function ---

function benchmark()
    println("🚀 Starting Benchmark...")
    
    # 1. Load Data
    # 1. Load Data using Phase5 to ensure STRICT consistency with Evolution
    println("📂 Loading CFD Data (via Phase5)...")
    # Phase5.load_wake_data handles reading, filtering (2<=x<=15), and normalization
    phase5_df = Phase5.load_wake_data("data/result_I0p3000_C22p0000.csv")
    
    # Convert to benchmark format
    bench_df = DataFrame()
    bench_df.x_D = phase5_df.x
    bench_df.r_D = phase5_df.r
    bench_df.u_def = phase5_df.deltaU
    bench_df.nut = phase5_df.nut
    
    println("✅ Data Loaded: $(nrow(bench_df)) points (Strict Match with Evolution)")
    
    # 2. Optimize Standard Models
    println("⚙️  Optimizing Jensen Model...")
    jensen_params, jensen_mse = optimize_jensen(bench_df)
    println("   Jensen MSE: $jensen_mse, Params: $jensen_params")
    
    println("⚙️  Optimizing Bastankhah Model...")
    bast_params, bast_mse = optimize_bastankhah(bench_df)
    println("   Bastankhah MSE: $bast_mse, Params: $bast_params")
    
    # 3. Optimize LLM Best Model (Re-optimization to ensure scale is correct)
    println("⚙️  Optimizing LLM Best Model (Structure from Gen 20)...")
    
    # Formula from Gen 20 Best: 
    # a * exp(-b*x) * exp(-c*r^2) * (1 + d*tanh(e*nut) * exp(-0.1*x) * (1 + f*abs(r)))^(-1.2) + g
    
    function optimize_llm(df)
        function loss(params)
            a, b, c, d, e, f, g = params
            mse = 0.0
            for row in eachrow(df)
                pred = llm_best_model(row.x_D, row.r_D, row.nut, params)
                mse += (pred - row.u_def)^2
            end
            return mse / nrow(df)
        end
        
        # Search range based on typical values
        # We use (0, 100) for stability, and (-1, 1) for offset g
        range = [
            (0.0, 100.0), # a
            (0.0, 10.0),  # b
            (0.0, 100.0), # c
            (0.0, 100.0), # d
            (0.0, 10.0),  # e
            (0.0, 100.0), # f
            (-1.0, 1.0)   # g
        ]
        
        res = bboptimize(loss; SearchRange = range, NumDimensions = 7, MaxTime = 120.0, TraceMode=:silent)
        return best_candidate(res), best_fitness(res)
    end

    llm_coeffs, llm_mse = optimize_llm(bench_df)
    println("   LLM Model MSE (Re-optimized): $llm_mse, Params: $llm_coeffs")
    
    # 4. Generate Plots
    println("📊 Generating Velocity Profiles...")
    
    # Define locations
    locs = [5.0, 10.0]
    
    for x_loc in locs
        # Extract data slice (approximate)
        tol = 0.1
        slice_df = filter(row -> abs(row.x_D - x_loc) < tol, bench_df)
        
        if nrow(slice_df) == 0
            println("Warning: No data found at x/D = $x_loc")
            continue
        end
        
        # Sort by r
        sort!(slice_df, :r_D)
        
        # Predictions
        r_vals = slice_df.r_D
        u_cfd = slice_df.u_def
        
        # Jensen
        A_j, k_j = jensen_params
        Rw_j = 0.5 + k_j * x_loc
        u_jensen = [abs(r) <= Rw_j ? A_j * (0.5/Rw_j)^2 : 0.0 for r in r_vals]
        
        # Bastankhah
        A_b, k_b, eps_b = bast_params
        sigma_b = k_b * x_loc + eps_b
        u_bast = [(A_b / sigma_b^2) * exp(-0.5 * (r / sigma_b)^2) for r in r_vals]
        
        # LLM
        u_llm = [llm_best_model(x_loc, row.r_D, row.nut, llm_coeffs) for row in eachrow(slice_df)]
        
        # Plot
        p = plot(r_vals, u_cfd, seriestype=:scatter, label="CFD (LES)", xlabel="Radial Distance (r/D)", ylabel="Velocity Deficit (Δu/U)", title="Wake Profile at x/D = $x_loc", legend=:topright, markersize=3, color=:black)
        plot!(p, r_vals, u_jensen, label="Jensen", linewidth=2, linestyle=:dash, color=:blue)
        plot!(p, r_vals, u_bast, label="Bastankhah", linewidth=2, linestyle=:dashdot, color=:orange)
        plot!(p, r_vals, u_llm, label="LLM (Best)", linewidth=3, color=:green)
        
        savefig(p, "results/plots/benchmark_profiles_x$(Int(x_loc)).png")
    end
    
    # 5. Save Summary
    open("results/plots/benchmark_summary.txt", "w") do io
        println(io, "Benchmark Results Summary")
        println(io, "=========================")
        println(io, "Generated on: $(Dates.now())")
        println(io, "")
        
        println(io, "1. Data Conditions (Strict Match with Evolution)")
        println(io, "------------------------------------------------")
        println(io, "Source:         data/result_I0p3000_C22p0000.csv")
        println(io, "Total Points:   $(nrow(bench_df))")
        println(io, "x/D Range:      $(minimum(bench_df.x_D)) to $(maximum(bench_df.x_D))")
        println(io, "r/D Range:      $(minimum(bench_df.r_D)) to $(maximum(bench_df.r_D))")
        println(io, "Deficit (Δu):   0.0 to 1.0 (Normalized)")
        println(io, "")
        
        println(io, "2. Model Performance & Parameters")
        println(io, "---------------------------------")
        
        println(io, "[Jensen Model]")
        println(io, "MSE:            $jensen_mse")
        println(io, "Formula:        A * (0.5 / (0.5 + k*x))^2")
        println(io, "Coefficients:   A=$(jensen_params[1]), k=$(jensen_params[2])")
        println(io, "")
        
        println(io, "[Bastankhah Model]")
        println(io, "MSE:            $bast_mse")
        println(io, "Formula:        (A / sigma^2) * exp(-0.5 * (r / sigma)^2)  where sigma = k*x + epsilon")
        println(io, "Coefficients:   A=$(bast_params[1]), k=$(bast_params[2]), epsilon=$(bast_params[3])")
        println(io, "")
        
        println(io, "[LLM Best Model (Gen 20)]")
        println(io, "MSE:            $llm_mse")
        println(io, "Formula:        a * exp(-b*x) * exp(-c*r^2) * (1 + d*tanh(e*nut) * exp(-0.1*x) * (1 + f*abs(r)))^(-1.2) + g")
        println(io, "Coefficients:   a=$(llm_coeffs[1]), b=$(llm_coeffs[2]), c=$(llm_coeffs[3]), d=$(llm_coeffs[4]), e=$(llm_coeffs[5]), f=$(llm_coeffs[6]), g=$(llm_coeffs[7])")
        println(io, "")
        
        println(io, "3. Comparative Analysis")
        println(io, "-----------------------")
        println(io, "Improvement over Jensen:     $(round((jensen_mse - llm_mse)/jensen_mse * 100, digits=2))%")
        println(io, "Improvement over Bastankhah: $(round((bast_mse - llm_mse)/bast_mse * 100, digits=2))%")
    end
    
    println("✅ Benchmark Complete! Results saved to results/plots/")
end

# Run
benchmark()
