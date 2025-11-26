#!/usr/bin/env julia

"""
Trace Evolution Lineage

Traces the evolutionary path of the best model across generations
and creates a visualization with LaTeX mathematical expressions.

Usage:
    julia --project=. trace_evolution_lineage.jl --exp-name trial_2
"""

using JSON3
using ArgParse
using Printf

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--exp-name"
            help = "Experiment name"
            arg_type = String
            default = "trial_2"
    end
    return parse_args(s)
end

"""
    load_history(filepath::String)

Load history from JSONL file
"""
function load_history(filepath::String)
    if !isfile(filepath)
        error("History file not found: $filepath")
    end
    
    history = []
    open(filepath, "r") do io
        for line in eachline(io)
            if !isempty(strip(line))
                entry = JSON3.read(line)
                push!(history, entry)
            end
        end
    end
    
    return history
end

"""
    to_latex(formula::String)

Convert Julia formula to LaTeX notation
"""
function to_latex(formula::String)
    latex = formula
    
    # Replace operators
    latex = replace(latex, "*" => " \\cdot ")
    latex = replace(latex, "exp(" => "e^{")
    
    # Handle exponentials - need to add closing braces
    # This is a simplified approach
    count = 0
    result = ""
    i = 1
    while i <= length(latex)
        if i <= length(latex) - 2 && latex[i:i+2] == "e^{"
            result *= "e^{"
            count += 1
            i += 3
        elseif latex[i] == ')'
            if count > 0
                result *= "}"
                count -= 1
            else
                result *= ")"
            end
            i += 1
        else
            result *= string(latex[i])
            i += 1
        end
    end
    latex = result
    
    # Replace power notation
    latex = replace(latex, r"([a-zA-Z0-9]+)\^(\(.*?\))" => s"\1^{\2}")
    latex = replace(latex, r"([a-zA-Z0-9]+)\^(-?[0-9\.]+)" => s"\1^{\2}")
    
    # Replace common functions
    latex = replace(latex, "sqrt(" => "\\sqrt{")
    latex = replace(latex, "tanh(" => "\\tanh(")
    latex = replace(latex, "abs(" => "|")
    latex = replace(latex, r"\\sqrt\{([^}]+)\}" => s"\\sqrt{\1}")
    
    # Handle division
    latex = replace(latex, " / " => " / ")
    
    # Wrap in display math
    latex = "\$\$ \\\\Delta U = " * latex * " \$\$"
    
    return latex
end

"""
    simplified_formula(formula::String)

Create a simplified version of the formula for display
"""
function simplified_formula(formula::String)
    # Extract key structural elements
    simplified = formula
    
    # Highlight key changes
    key_features = String[]
    
    # Check for power law decay
    if occursin(r"x\^(-?[0-9\.]+)", formula)
        m = match(r"x\^(-?[0-9\.]+)", formula)
        push!(key_features, "x^{$(m.captures[1])}")
    end
    
    # Check for TKE terms
    if occursin(r"k\^([0-9\.]+)", formula)
        m = match(r"k\^([0-9\.]+)", formula)
        push!(key_features, "k^{$(m.captures[1])}")
    elseif occursin("sqrt(k)", formula)
        push!(key_features, "\\sqrt{k}")
    elseif occursin("/ (1 + ", formula) && occursin("*k", formula)
        push!(key_features, "TKE term")
    end
    
    # Check for near-wake correction
    if occursin("exp(-x)", formula) || occursin("exp(-c*x)", formula)
        push!(key_features, "near-wake")
    end
    
    return join(key_features, ", ")
end

"""
    trace_lineage(history::Vector)

Trace the lineage of champion models through generations
"""
function trace_lineage(history::Vector)
    lineage = []
    
    for h in history
        push!(lineage, (
            generation = h.generation,
            formula = h.best_model.formula,
            score = h.best_score,
            reason = get(h.best_model, :reason, ""),
            ep_type = get(h.best_model, :ep_type, "EP1")
        ))
    end
    
    return lineage
end

"""
    create_evolution_graph(lineage::Vector)

Create a Mermaid graph showing the evolution path
"""
function create_evolution_graph(lineage::Vector)
    graph = "```mermaid\ngraph TD\n"
    
    # Define nodes for each generation's best model
    for l in lineage
        gen = l.generation
        score = round(l.score * 1000, digits=3)  # Convert to ×10^-3
        
        # Simplified formula for node label
        formula_short = l.formula
        # Truncate if too long
        if length(formula_short) > 40
            formula_short = formula_short[1:37] * "..."
        end
        
        # Escape special characters for Mermaid
        formula_short = replace(formula_short, "\"" => "'")
        
        node_id = "G$gen"
        label = "Gen $gen<br/>Score: $(score)×10⁻³<br/>$(l.ep_type)"
        
        graph *= "    $node_id[\"$label\"]\n"
    end
    
    graph *= "\n"
    
    # Add edges based on evolution strategy
    for i in 2:length(lineage)
        current = lineage[i]
        prev = lineage[i-1]
        
        edge_label = ""
        edge_style = ""
        
        # Determine relationship based on EP type
        if current.ep_type == "EP2"
            edge_label = "Improvement"
            edge_style = " --> "
        elseif current.ep_type == "EP4"
            edge_label = "Simplification"
            edge_style = " -.-> "
        elseif current.ep_type == "EP3"
            edge_label = "Physics Fix"
            edge_style = " ==> "
        else
            edge_label = "New Structure"
            edge_style = " ~~> "
        end
        
        graph *= "    G$(prev.generation)$edge_style|$edge_label| G$(current.generation)\n"
    end
    
    # Add styling
    graph *= "\n"
    graph *= "    classDef milestone fill:#f96,stroke:#333,stroke-width:4px\n"
    graph *= "    classDef final fill:#9f6,stroke:#333,stroke-width:4px\n"
    
    # Highlight milestones
    milestones = [1, 3, 6, 8, 10, 13, 17]
    for m in milestones
        if m <= length(lineage)
            graph *= "    class G$m milestone\n"
        end
    end
    graph *= "    class G$(length(lineage)) final\n"
    
    graph *= "```\n"
    
    return graph
end

"""
    create_lineage_markdown(lineage::Vector, output_path::String)

Create a markdown document showing the evolution lineage
"""
function create_lineage_markdown(lineage::Vector, output_path::String)
    io_buffer = IOBuffer()
    
    println(io_buffer, "# Model Evolution Lineage")
    println(io_buffer, "")
    println(io_buffer, "## Evolution Path from Generation 1 to $(length(lineage))")
    println(io_buffer, "")
    println(io_buffer, "This document traces the evolutionary path of the champion model,")
    println(io_buffer, "showing how the mathematical structure evolved across generations.")
    println(io_buffer, "")
    
    # Add evolution graph
    println(io_buffer, "## Evolution Graph")
    println(io_buffer, "")
    println(io_buffer, "The following diagram shows the lineage from Generation 1 (origin) to Generation $(length(lineage)) (final best model).")
    println(io_buffer, "Edge types indicate the evolution strategy:")
    println(io_buffer, "- Solid arrow (→): Improvement (EP2)")
    println(io_buffer, "- Dashed arrow (-→): Simplification (EP4)")
    println(io_buffer, "- Bold arrow (⇒): Physics Fix (EP3)")
    println(io_buffer, "- Wavy arrow (~→): New Structure (EP1)")
    println(io_buffer, "")
    println(io_buffer, create_evolution_graph(lineage))
    println(io_buffer, "")
    
    # Track major milestones
    println(io_buffer, "## Major Milestones")
    println(io_buffer, "")
    
    # Identify key transition points
    milestones = [
        (1, "Initial exploration"),
        (3, "Simplified structure"),
        (6, "TKE term refinement"),
        (8, "Near-wake correction added"),
        (10, "Removal of near-wake term"),
        (11, "Re-addition of near-wake term"),
        (13, "TKE power optimization"),
        (17, "Decay rate fine-tuning"),
        (20, "Final convergence")
    ]
    
    for (gen, milestone) in milestones
        if gen <= length(lineage)
            l = lineage[gen]
            println(io_buffer, "### Generation $gen: $milestone")
            println(io_buffer, "")
            println(io_buffer, "**Strategy**: $(l.ep_type)")
            println(io_buffer, "")
            println(io_buffer, "**Score**: $(round(l.score, digits=8))")
            println(io_buffer, "")
            println(io_buffer, "**Formula**:")
            println(io_buffer, "```")
            println(io_buffer, l.formula)
            println(io_buffer, "```")
            println(io_buffer, "")
            println(io_buffer, "**Reasoning**: $(l.reason)")
            println(io_buffer, "")
        end
    end
    
    # Full generation-by-generation history
    println(io_buffer, "## Complete Evolution History")
    println(io_buffer, "")
    
    for (i, l) in enumerate(lineage)
        improvement = if i > 1
            prev_score = lineage[i-1].score
            rel_imp = (prev_score - l.score) / prev_score * 100
            rel_imp > 0 ? " (↓ $(round(rel_imp, digits=2))%)" : " (↑ $(round(-rel_imp, digits=2))%)"
        else
            ""
        end
        
        println(io_buffer, "### Generation $(l.generation)")
        println(io_buffer, "")
        println(io_buffer, "- **Strategy**: $(l.ep_type)")
        println(io_buffer, "- **Score**: $(round(l.score, digits=8))$improvement")
        println(io_buffer, "")
        println(io_buffer, "**Formula**:")
        println(io_buffer, "```")
        println(io_buffer, l.formula)
        println(io_buffer, "```")
        println(io_buffer, "")
        if !isempty(l.reason)
            println(io_buffer, "_$(l.reason)_")
            println(io_buffer, "")
        end
        println(io_buffer, "---")
        println(io_buffer, "")
    end
    
    # Summary table
    println(io_buffer, "## Evolution Summary Table")
    println(io_buffer, "")
    println(io_buffer, "| Gen | Strategy | Score | Key Change |")
    println(io_buffer, "|-----|----------|-------|------------|")
    
    for l in lineage
        key_change = simplified_formula(l.formula)
        @printf(io_buffer, "| %2d | %s | %.6f | %s |\n", 
                l.generation, l.ep_type, l.score, key_change)
    end
    println(io_buffer, "")
    
    # Statistical summary
    println(io_buffer, "## Statistical Summary")
    println(io_buffer, "")
    scores = [l.score for l in lineage]
    initial_score = scores[1]
    final_score = scores[end]
    total_improvement = (initial_score - final_score) / initial_score * 100
    
    println(io_buffer, "- **Initial Score (Gen 1)**: $(round(initial_score, digits=8))")
    println(io_buffer, "- **Final Score (Gen $(length(lineage)))**: $(round(final_score, digits=8))")
    println(io_buffer, "- **Total Improvement**: $(round(total_improvement, digits=2))%")
    println(io_buffer, "- **Best Score**: $(round(minimum(scores), digits=8)) (Gen $(findmin(scores)[2]))")
    println(io_buffer, "")
    
    # Write to file
    content = String(take!(io_buffer))
    mkpath(dirname(output_path))
    write(output_path, content)
    
    @info "Lineage markdown saved to: $output_path"
    
    return content
end

# Main execution
function main()
    args = parse_commandline()
    exp_name = args["exp-name"]
    
    println("\n" * "="^70)
    println("📊 Tracing Evolution Lineage")
    println("="^70)
    println("\nExperiment: $exp_name")
    
    # Load history
    base_dir = joinpath("results", exp_name)
    history_path = joinpath(base_dir, "history.jsonl")
    
    println("\n📂 Loading history from: $history_path")
    history = load_history(history_path)
    println("   ✓ Loaded $(length(history)) generations")
    
    # Trace lineage
    println("\n🔍 Tracing lineage...")
    lineage = trace_lineage(history)
    
    # Create markdown
    output_path = joinpath(base_dir, "evolution_lineage.md")
    println("\n📝 Creating lineage markdown...")
    create_lineage_markdown(lineage, output_path)
    
    println("\n✅ Lineage Analysis Complete!")
    println("\nOutput: $output_path")
    println("="^70)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
