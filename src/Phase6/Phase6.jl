module Phase6

using CSV, DataFrames
using BlackBoxOptim
using Statistics
using Printf

# Submodules
include("DataLoader.jl")
include("Physics.jl")
include("ReasonScorer.jl")
include("Evaluator.jl")
include("Optimizer.jl")

using .DataLoader
using .Physics
using .ReasonScorer
using .Evaluator
using .Optimizer

export evaluate_formula, load_wake_data

# Global Data Cache
const DATA_LOADED = Ref(false)
const WAKE_DATA = Ref{DataFrame}()

function load_wake_data(csv_path::String)
    if !DATA_LOADED[]
        @info "Loading wake data from: $csv_path"
        WAKE_DATA[] = DataLoader.load_wake_csv(csv_path)
        DATA_LOADED[] = true
        @info "Data loaded: $(size(WAKE_DATA[])) rows"
    end
    return WAKE_DATA[]
end

"""
    evaluate_formula(model_str::String; num_coeffs=4, with_penalty=true, csv_path="...")

Evaluates a model formula using Phase 6 logic (MSE + Physics + Reason).
Note: Reason scoring requires the 'reason' string, which is not passed here. 
This function is primarily for numerical evaluation. 
For full evaluation including reason, use `evaluate_model_full`.
"""
function evaluate_formula(model_str::String;
                          num_coeffs::Int=4,
                          with_penalty::Bool=true,
                          csv_path::String="data/result_I0p3000_C22p0000.csv")
    
    df = load_wake_data(csv_path)
    
    # Parse expression
    ex = Evaluator.parse_model_expression(model_str)
    if ex === nothing
        return (Inf, nothing)
    end
    
    # Optimize Coefficients (using DE)
    # Optimizer now uses Physics module for penalty calculation
    θ_opt, mse_score, physics_penalty = Optimizer.optimize_coefficients(
        ex, df;
        num_coeffs=num_coeffs,
        with_penalty=with_penalty
    )
    
    # Combine scores (MSE + Physics)
    # Note: Reason score is not included here as we don't have the reason text.
    # This function returns the numerical fitness.
    
    # Final Score Calculation
    # We use a multiplicative penalty formulation: Score = MSE * (1 + Penalty)
    final_score = mse_score * (1.0 + physics_penalty)
    
    return (final_score, θ_opt)
end

end # module Phase6
