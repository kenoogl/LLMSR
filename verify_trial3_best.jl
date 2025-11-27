using CSV
using DataFrames
using Statistics
using BlackBoxOptim
using JSON3

# Include necessary modules
include("src/Phase5.jl")
using .Phase5

function verify_trial3()
    println("🚀 Verifying Trial 3 Best Model Score...")
    
    # 1. Load Data
    println("📂 Loading CFD Data (via Phase5)...")
    phase5_df = Phase5.load_wake_data("data/result_I0p3000_C22p0000.csv")
    
    # Convert to benchmark format
    bench_df = DataFrame()
    bench_df.x_D = phase5_df.x
    bench_df.r_D = phase5_df.r
    bench_df.u_def = phase5_df.deltaU
    bench_df.nut = phase5_df.nut
    bench_df.k = phase5_df.k
    bench_df.omega = phase5_df.omega
    
    println("✅ Data Loaded: $(nrow(bench_df)) points")
    
    # 2. Define Model
    llm_formula_str = "a * (1 + b*x)^(-2) * (1 + c*r^2)^(-1) + d * (1 + e*x^2)^(-1)"
    num_coeffs = 5
    println("   Formula: $llm_formula_str")
    
    # Parse expression
    llm_expr = Phase5.Evaluator.parse_model_expression(llm_formula_str)
    if llm_expr === nothing
        error("Failed to parse LLM model expression")
    end

    println("⚙️  Optimizing LLM Best Model...")
    
    # Optimization function using Phase5.Evaluator
    function optimize_llm(df, expr, n_coeffs)
        # Pre-extract vectors for speed
        x_vec = df.x_D
        r_vec = df.r_D
        k_vec = df.k
        omega_vec = df.omega
        nut_vec = df.nut
        target_vec = df.u_def
        
        function loss(params)
            # Use Phase5.Evaluator.mse_eval which handles vectorization
            return Phase5.Evaluator.mse_eval(expr, params, x_vec, r_vec, k_vec, omega_vec, nut_vec, target_vec)
        end
        
        # Dynamic search range: -100.0 to 100.0 for all coeffs
        range = [(-100.0, 100.0) for _ in 1:n_coeffs]
        
        # Increase time to ensure convergence
        res = bboptimize(loss; SearchRange = range, NumDimensions = n_coeffs, MaxTime = 60.0, TraceMode=:verbose)
        return best_candidate(res), best_fitness(res)
    end

    llm_coeffs, llm_mse = optimize_llm(bench_df, llm_expr, num_coeffs)
    println("   LLM Model MSE (Re-optimized): $llm_mse")
    println("   Coeffs: $llm_coeffs")
end

verify_trial3()
