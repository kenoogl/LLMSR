using JSON3
using Dates
using ArgParse

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--exp-name"
            help = "Experiment name"
            arg_type = String
            required = true
    end
    return parse_args(s)
end

function fix_history(exp_name::String)
    results_dir = joinpath("results", exp_name)
    history_path = joinpath(results_dir, "history.jsonl")
    backup_path = joinpath(results_dir, "history.jsonl.bak")
    
    if !isfile(history_path)
        println("❌ History file not found: $history_path")
        return
    end
    
    # Backup original file
    cp(history_path, backup_path, force=true)
    println("📦 Backed up history to: $backup_path")
    
    # Load history
    history = []
    for line in eachline(history_path)
        push!(history, JSON3.read(line))
    end
    println("📂 Loaded $(length(history)) generations from history.jsonl")
    
    # Load models files to build ID map
    # Map: generation -> (formula, reason) -> (id, parent_id, parent_gen)
    id_map = Dict{Int, Dict{Any, Any}}()
    
    files = readdir(results_dir)
    gen_files = filter(f -> occursin(r"models_gen\d+\.json", f), files)
    
    println("📂 Loading $(length(gen_files)) models_gen*.json files...")
    
    for f in gen_files
        path = joinpath(results_dir, f)
        data = JSON3.read(read(path, String))
        gen = data.generation
        
        if !haskey(id_map, gen)
            id_map[gen] = Dict{String, Any}()
        end
        
        if haskey(data, :models)
            for m in data.models
                # Normalize formula for matching (remove spaces)
                formula = replace(m.formula, " " => "")
                reason = haskey(m, :reason) ? m.reason : ""
                
                # Use composite key: (formula, reason)
                key = (formula, reason)
                
                id_map[gen][key] = (
                    id = m.id,
                    parent_id = haskey(m, :parent_id) ? m.parent_id : nothing,
                    parent_gen = haskey(m, :parent_generation) ? m.parent_generation : nothing
                )
            end
        end
    end
    
    # Reconstruct history with IDs
    new_history = []
    fixed_count = 0
    
    for h in history
        gen = h.generation
        
        new_models = []
        if haskey(h, :all_models)
            for m in h.all_models
                formula = replace(m.formula, " " => "")
                reason = haskey(m, :reason) ? m.reason : ""
                key = (formula, reason)
                
                # Default values
                id = haskey(m, :id) ? m.id : 0
                parent_id = haskey(m, :parent_id) ? m.parent_id : nothing
                parent_gen = haskey(m, :parent_generation) ? m.parent_generation : nothing
                
                # Always try to find correct ID using composite key
                if haskey(id_map, gen) && haskey(id_map[gen], key)
                    info = id_map[gen][key]
                    id = info.id
                    # Also update parent info if missing or if we are correcting it
                    if parent_id === nothing || parent_id == 0
                        parent_id = info.parent_id
                        parent_gen = info.parent_gen
                    end
                    fixed_count += 1
                end
                
                # Create new dict with ID
                new_m = Dict(
                    "id" => id,
                    "formula" => m.formula,
                    "score" => m.score,
                    "coefficients" => m.coefficients,
                    "reason" => haskey(m, :reason) ? m.reason : "",
                    "ep_type" => haskey(m, :ep_type) ? m.ep_type : "",
                    "parent_generation" => parent_gen,
                    "parent_id" => parent_id
                )
                push!(new_models, new_m)
            end
        end
        
        # Create new history entry
        new_entry = Dict(
            "generation" => gen,
            "timestamp" => haskey(h, :timestamp) ? h.timestamp : string(now()),
            "best_score" => h.best_score,
            "mean_score" => h.mean_score,
            "best_model" => h.best_model,
            "all_models" => new_models
        )
        push!(new_history, new_entry)
    end
    
    println("✅ Fixed IDs for $fixed_count models")
    
    # Save new history
    open(history_path, "w") do io
        for entry in new_history
            JSON3.write(io, entry)
            write(io, "\n")
        end
    end
    
    println("💾 Saved repaired history to: $history_path")
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_commandline()
    fix_history(args["exp-name"])
end
