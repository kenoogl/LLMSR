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

function test_offset()
    println("🚀 Starting Offset Test for Trial 2 Champion...")
    
    # 1. Load Data
    println("📂 Loading CFD Data...")
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
    
    # 2. Define Models
    # Original Trial 2 Champion
    formula_orig = "x^(-0.596) * exp(-a*r^2) / (1 + b*k^0.9505) * (1 - exp(-x))"
    # With Offset
    formula_offset = "x^(-0.596) * exp(-a*r^2) / (1 + b*k^0.9505) * (1 - exp(-x)) + c"
    
    println("\n📝 Model Definitions:")
    println("  Original: $formula_orig")
    println("  Offset:   $formula_offset")
    
    # 3. Optimize
    function optimize_model(df, formula, n_coeffs)
        println("\n⚙️  Optimizing: $formula")
        expr = Phase5.Evaluator.parse_model_expression(formula)
        
        x_vec = df.x_D
        r_vec = df.r_D
        k_vec = df.k
        omega_vec = df.omega
        nut_vec = df.nut
        target_vec = df.u_def
        
        function loss(params)
            return Phase5.Evaluator.mse_eval(expr, params, x_vec, r_vec, k_vec, omega_vec, nut_vec, target_vec)
        end
        
        # Search range: -1.0 to 1.0 for offset (c), 0.0 to 100.0 for others
        # Assuming 'c' is the last parameter if extracted in order?
        # Phase5.Evaluator extracts params. Let's assume broad range for all.
        range = [(-10.0, 100.0) for _ in 1:n_coeffs]
        
        res = bboptimize(loss; SearchRange = range, NumDimensions = n_coeffs, MaxTime = 60.0, TraceMode=:silent)
        return best_candidate(res), best_fitness(res), expr
    end
    
    # Optimize Original
    coeffs_orig, mse_orig, expr_orig = optimize_model(bench_df, formula_orig, 2)
    println("   MSE (Original): $mse_orig")
    println("   Coeffs: $coeffs_orig")
    
    # Optimize With Offset
    coeffs_offset, mse_offset, expr_offset = optimize_model(bench_df, formula_offset, 3)
    println("   MSE (With Offset): $mse_offset")
    println("   Coeffs: $coeffs_offset")
    
    # 4. Compare
    improvement = (mse_orig - mse_offset) / mse_orig * 100
    println("\n📊 Comparison:")
    println("  Original MSE: $mse_orig")
    println("  Offset MSE:   $mse_offset")
    println("  Improvement:  $(round(improvement, digits=2))%")
    
    # 5. Plot Profiles
    println("\n📈 Generating Comparison Plots...")
    plots_dir = "results/trial_2/plots_offset_test"
    mkpath(plots_dir)
    
    locs = [5.0, 10.0]
    for x_loc in locs
        tol = 0.1
        slice_df = filter(row -> abs(row.x_D - x_loc) < tol, bench_df)
        if nrow(slice_df) == 0 continue end
        sort!(slice_df, :r_D)
        
        r_vals = slice_df.r_D
        u_cfd = slice_df.u_def
        
        u_orig = Phase5.Evaluator.eval_model(expr_orig, coeffs_orig, fill(x_loc, nrow(slice_df)), slice_df.r_D, slice_df.k, slice_df.omega, slice_df.nut)
        u_offset = Phase5.Evaluator.eval_model(expr_offset, coeffs_offset, fill(x_loc, nrow(slice_df)), slice_df.r_D, slice_df.k, slice_df.omega, slice_df.nut)
        
        p = plot(r_vals, u_cfd, seriestype=:scatter, label="CFD", xlabel="r/D", ylabel="Δu/U", title="x/D = $x_loc (Offset Test)")
        plot!(p, r_vals, u_orig, label="Original", linewidth=2)
        plot!(p, r_vals, u_offset, label="With Offset", linewidth=2, linestyle=:dash)
        
        savefig(p, joinpath(plots_dir, "profile_x$(Int(x_loc)).png"))
    end
    println("✅ Plots saved to $plots_dir")
end

test_offset()
