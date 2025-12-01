module Optimizer

using BlackBoxOptim
using ..Evaluator
using ..Physics

export optimize_coefficients

function optimize_coefficients(ex, df; num_coeffs=4, with_penalty=true)
    
    x = df.x
    r = df.r
    k = df.k
    omega = df.omega
    nut = df.nut
    deltaU = df.deltaU
    
    function loss(θ)
        # 1. MSE
        mse = Evaluator.mse_eval(ex, θ, x, r, k, omega, nut, deltaU)
        
        # 2. Physics Penalty (if enabled)
        penalty = 0.0
        if with_penalty
            # Need to evaluate model again to get predictions for penalty check
            # Or pass predictions if mse_eval returned them (it doesn't currently)
            # Re-evaluating is safer but slower. 
            # For optimization loop, we might want to integrate them.
            # Here we re-evaluate for clarity.
            y_pred = Evaluator.eval_model(ex, θ, x, r, k, omega, nut)
            penalty = Physics.calculate_penalty(y_pred, deltaU, x, r, k, omega, nut, θ)
        end
        
        # Combined Objective for DE
        # We want to minimize MSE, but also minimize Penalty.
        # Objective = MSE * (1 + Penalty)
        return mse * (1.0 + penalty)
    end
    
    # Search Range
    # Allow negative coefficients as per recent learnings
    search_range = [(-100.0, 100.0) for _ in 1:num_coeffs]
    
    # Optimization
    res = bboptimize(loss; 
        SearchRange = search_range, 
        NumDimensions = num_coeffs, 
        MaxTime = 5.0, # Fast optimization for evolution loop
        TraceMode = :silent
    )
    
    best_θ = best_candidate(res)
    best_fitness_val = best_fitness(res)
    
    # Decompose score for reporting
    # We need to return MSE and Penalty separately if possible, 
    # but best_fitness returns the combined value.
    # Let's re-calculate to separate them.
    final_mse = Evaluator.mse_eval(ex, best_θ, x, r, k, omega, nut, deltaU)
    
    final_penalty = 0.0
    if with_penalty
        y_pred = Evaluator.eval_model(ex, best_θ, x, r, k, omega, nut)
        final_penalty = Physics.calculate_penalty(y_pred, deltaU, x, r, k, omega, nut, best_θ)
    end
    
    return best_θ, final_mse, final_penalty
end

end # module
