using JSON3
using Dates
using Statistics
using ArgParse
using Printf

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--exp-name"
            help = "Experiment name"
            arg_type = String
            default = "default"
    end
    return parse_args(s)
end

function load_history(filepath)
    history = []
    if isfile(filepath)
        for line in eachline(filepath)
            push!(history, JSON3.read(line))
        end
    end
    return history
end

function load_benchmark(filepath)
    if isfile(filepath)
        return read(filepath, String)
    end
    return "Benchmark not run yet."
end

function main()
    args = parse_commandline()
    exp_name = args["exp-name"]
    
    base_dir = joinpath("results", exp_name)
    history_path = joinpath(base_dir, "history.jsonl")
    benchmark_path = joinpath(base_dir, "plots", "benchmark_summary.txt")
    output_path = joinpath(base_dir, "report_context.md")
    
    println("📝 Preparing report context for experiment: $exp_name")
    
    # Load data
    history = load_history(history_path)
    benchmark_text = load_benchmark(benchmark_path)
    
    if isempty(history)
        println("❌ No history found at $history_path")
        return
    end
    
    # Analyze history
    best_initial = history[1].best_score
    best_final = history[end].best_score
    improvement = (best_initial - best_final) / best_initial * 100
    
    best_model_final = history[end].best_model
    
    # Generate Context Markdown
    open(output_path, "w") do io
        println(io, "# Experiment Report Context: $exp_name")
        println(io, "")
        println(io, "## 1. Overview")
        println(io, "- **Date**: $(Dates.now())")
        println(io, "- **Total Generations**: $(length(history))")
        println(io, "- **Initial Best Score**: $(@sprintf("%.6f", best_initial))")
        println(io, "- **Final Best Score**: $(@sprintf("%.6f", best_final))")
        println(io, "- **Improvement**: $(@sprintf("%.2f", improvement))%")
        println(io, "")
        
        println(io, "## 2. Best Model Discovered")
        println(io, "### Formula")
        println(io, "```julia")
        println(io, best_model_final.formula)
        println(io, "```")
        println(io, "")
        println(io, "### Coefficients")
        println(io, "```julia")
        println(io, best_model_final.coefficients)
        println(io, "```")
        println(io, "")
        println(io, "### Reason (LLM)")
        println(io, "> $(best_model_final.reason)")
        println(io, "")
        
        println(io, "## 3. Evolution History")
        println(io, "| Gen | Best Score | Mean Score | Best Formula (Truncated) |")
        println(io, "|---|---|---|---|")
        for h in history
            f_trunc = length(h.best_model.formula) > 40 ? h.best_model.formula[1:37] * "..." : h.best_model.formula
            println(io, "| $(h.generation) | $(@sprintf("%.6f", h.best_score)) | $(@sprintf("%.6f", h.mean_score)) | `$(f_trunc)` |")
        end
        println(io, "")
        
        println(io, "## 4. Benchmark Results")
        println(io, "```")
        println(io, benchmark_text)
        println(io, "```")
        println(io, "")
        
        println(io, "## 5. Instructions for Report Generation")
        println(io, "Please write a comprehensive technical report based on the data above.")
        println(io, "The report should include:")
        println(io, "1. **Executive Summary**: Key findings and performance improvement.")
        println(io, "2. **Methodology**: Brief mention of the evolutionary process.")
        println(io, "3. **Results Analysis**: Discuss the evolution trend and the final model structure.")
        println(io, "4. **Physical Interpretation**: Explain the physical meaning of the terms in the best model (e.g., TKE influence, decay rates).")
        println(io, "5. **Comparison**: Discuss how it compares to standard models (Jensen, Bastankhah) based on the benchmark results.")
        println(io, "6. **Conclusion**: Final thoughts and future recommendations.")
    end
    
    println("✅ Report context generated: $output_path")
    println("📋 Copy the content of this file and paste it to the LLM to generate the final report.")
end

main()
