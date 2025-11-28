#!/usr/bin/env julia

"""
Model Inspection Script

特定の世代・IDのモデルを個別に評価・可視化するためのツール。
CFDデータとの比較プロットを生成し、局所最適化による詳細な係数調整を行う。

使用方法:
    julia --project=. inspect_model.jl --gen N [--id ID | --best] [--x-locs "5.0,10.0"]
"""

using ArgParse
using JSON3
using CSV
using DataFrames
using Plots
using Statistics
using BlackBoxOptim

# Include necessary modules
include("src/Phase5.jl")
using .Phase5

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--gen"
            help = "Generation number"
            arg_type = Int
            required = true
        "--id"
            help = "Model ID (optional if --best is used)"
            arg_type = Int
            default = 0
        "--best"
            help = "Select the best model of the generation"
            action = :store_true
        "--x-locs"
            help = "Comma-separated x/D locations to plot (default: 5.0,10.0)"
            arg_type = String
            default = "5.0,10.0"
        "--exp-name"
            help = "Experiment name"
            arg_type = String
            default = "default"
    end
    return parse_args(s)
end

function load_cfd_data()
    println("📂 Loading CFD Data (via Phase5)...")
    # Phase5.load_wake_data handles reading, filtering (2<=x<=15), and normalization
    phase5_df = Phase5.load_wake_data("data/result_I0p3000_C22p0000.csv")
    
    # Convert to benchmark format
    bench_df = DataFrame()
    bench_df.x_D = phase5_df.x
    bench_df.r_D = phase5_df.r
    bench_df.u_def = phase5_df.deltaU
    bench_df.nut = phase5_df.nut
    
    return bench_df
end

function evaluate_model(formula_str, coeffs, x, r, nut)
    # Parse the formula string into a Julia expression
    # We replace coefficients 'a', 'b', etc. with 'p[1]', 'p[2]'...
    # and create a function (x, r, nut, p) -> result
    
    # Map of variable names to coefficient indices
    vars = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j']
    
    expr_str = formula_str
    for (i, v) in enumerate(vars)
        if i <= length(coeffs)
            expr_str = replace(expr_str, Regex("\\b$v\\b") => "p[$i]")
        end
    end
    
    # Create function
    func_expr = Meta.parse("(x, r, nut, p) -> $expr_str")
    func = eval(func_expr)
    
    try
        return Base.invokelatest(func, x, r, nut, coeffs)
    catch e
        return NaN
    end
end

function main()
    args = parse_commandline()
    gen = args["gen"]
    model_id = args["id"]
    use_best = args["best"]
    x_locs_str = args["x-locs"]
    x_locs = parse.(Float64, split(x_locs_str, ","))
    exp_name = args["exp-name"]
    
    base_dir = joinpath("results", exp_name)
    plots_dir = joinpath(base_dir, "plots")
    mkpath(plots_dir)

    # Load Feedback JSON
    json_path = joinpath(base_dir, "feedback_gen$(gen).json")
    if !isfile(json_path)
        println("❌ Error: Feedback file not found: $json_path")
        return
    end
    
    println("📂 Loading Generation $gen data...")
    json_data = JSON3.read(read(json_path, String))
    
    target_model = nothing
    if use_best
        target_model = json_data.best_model
        println("🎯 Selected Best Model")
    elseif model_id > 0
        # Find model by ID
        for m in json_data.evaluated_models
            if m.id == model_id
                target_model = m
                break
            end
        end
        if target_model === nothing
            println("❌ Error: Model ID $model_id not found in Generation $gen")
            return
        end
        println("🎯 Selected Model ID: $model_id")
    else
        println("❌ Error: Must specify --id or --best")
        return
    end
    
    # Load CFD Data for optimization and plotting
    bench_df = load_cfd_data()
    println("✅ Data Loaded: $(nrow(bench_df)) points")

    # We will perform local optimization using BlackBoxOptim to ensure consistency
    # between the optimization objective and the plotting evaluation.
    
    # 1. Prepare Data for Optimization
    # We use the loaded bench_df
    # Filter for valid range (MATCHING benchmark_models.jl)
    opt_df = filter(row -> row.x_D > 0.1, bench_df)
    
    # 2. Prepare Evaluation Function
    # Identify variables in formula
    potential_coeffs = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j']
    found_coeffs = Char[]
    for c in potential_coeffs
        if occursin(Regex("\\b$c\\b"), target_model.formula)
            push!(found_coeffs, c)
        end
    end
    max_var = isempty(found_coeffs) ? 'a' : maximum(found_coeffs)
    num_coeffs = Int(max_var) - Int('a') + 1
    num_coeffs = max(num_coeffs, 7) # At least 7
    
    println("   Optimizing $num_coeffs coefficients locally (Data: x > 0.1)...")
    
    # Create a string with p[i] replacements
    expr_str = target_model.formula
    for (i, c) in enumerate(potential_coeffs)
        if i <= num_coeffs
            expr_str = replace(expr_str, Regex("\\b$c\\b") => "p[$i]")
        end
    end
    
    func_expr = Meta.parse("(x, r, nut, p) -> $expr_str")
    model_func = eval(func_expr)
    
    # 3. Define Loss Function
    function loss(p)
        mse = 0.0
        n = nrow(opt_df)
        for row in eachrow(opt_df)
            val = try
                Base.invokelatest(model_func, row.x_D, row.r_D, row.nut, p)
            catch
                1e9
            end
            mse += (val - row.u_def)^2
        end
        return mse / n
    end
    
    # 4. Run Optimization
    # Use broader range to allow negative offsets
    range = [(-100.0, 100.0) for _ in 1:num_coeffs]
    
    res = bboptimize(loss; SearchRange = range, NumDimensions = num_coeffs, MaxTime = 120.0, TraceMode=:silent)
    
    new_coeffs = best_candidate(res)
    score = best_fitness(res)
    
    # Final result is already in new_coeffs and score
    
    println("   Old Coeffs: $(target_model.coefficients)")
    println("   New Coeffs: $new_coeffs")
    println("   New Score:  $score")
    
    # Load CFD Data for plotting (we still need this locally)
    bench_df = load_cfd_data()
    println("✅ Data Loaded: $(nrow(bench_df)) points")
    
    # Generate Plots
    println("📊 Generating Plots...")
    
    for x_loc in x_locs
        # Extract data slice
        tol = 0.1
        slice_df = filter(row -> abs(row.x_D - x_loc) < tol, bench_df)
        
        if nrow(slice_df) == 0
            println("Warning: No data found at x/D = $x_loc")
            continue
        end
        
        sort!(slice_df, :r_D)
        
        r_vals = slice_df.r_D
        u_cfd = slice_df.u_def
        
        # Predict using new coefficients
        # We can use Phase5.Evaluator.eval_model if accessible, or our local evaluate_model
        # Let's use our local evaluate_model but update it to handle the vector coeffs
        u_pred = Float64[]
        for row in eachrow(slice_df)
            val = evaluate_model(target_model.formula, new_coeffs, x_loc, row.r_D, row.nut)
            push!(u_pred, val)
        end
        
        # Plot
        title_str = use_best ? "Gen $gen Best Model (Re-optimized)" : "Gen $gen Model $model_id (Re-optimized)"
        p = plot(r_vals, u_cfd, seriestype=:scatter, label="CFD (LES)", 
                 xlabel="Radial Distance (r/D)", ylabel="Velocity Deficit (Δu/U)", 
                 title="$title_str at x/D = $x_loc", legend=:topright, 
                 markersize=3, color=:black, alpha=0.5,
                 size=(1200, 800))
        
        plot!(p, r_vals, u_pred, label="Model Prediction", linewidth=3, color=:red)
        
        # Save
        filename = use_best ? "inspect_gen$(gen)_best_x$(Int(x_loc)).png" : "inspect_gen$(gen)_model$(model_id)_x$(Int(x_loc)).png"
        output_path = joinpath(plots_dir, filename)
        savefig(p, output_path)
        println("   Saved: $output_path")
    end
    
    println("✅ Inspection Complete!")
end

main()
