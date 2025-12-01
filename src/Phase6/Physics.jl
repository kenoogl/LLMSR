module Physics

using Statistics

export calculate_penalty

"""
    calculate_penalty(y_pred, y_target, x, r, k, omega, nut, coeffs)

Calculates the total physical penalty for a given model prediction.
"""
function calculate_penalty(y_pred, y_target, x, r, k, omega, nut, coeffs)
    
    # 1. Non-Physical Value Check (Negative Deficit or Too Large)
    # ΔU should be between 0 and 1 (approx)
    # Penalty if ΔU < 0 or ΔU > 1.5 (allow some overshoot but penalize)
    p_range = mean((y_pred .< -0.01) .* abs.(y_pred) .* 10.0 .+ (y_pred .> 1.2) .* abs.(y_pred .- 1.2) .* 10.0)
    
    # 2. Monotonic Decay in x (Streamwise)
    # Ideally, for r=0, d(ΔU)/dx < 0.
    # We can check this by looking at the trend.
    # Simplified check: Compare mean values at different downstream distances if data allows,
    # or just penalize if the global trend is increasing.
    # Here, we use a heuristic based on the coefficients if possible, or numerical gradient.
    # For general algebraic forms, numerical check is safer.
    
    # 3. Symmetry in r
    # The model should be symmetric in r. 
    # Most generated models like r^2 or abs(r) are symmetric.
    # If the model contains odd powers of r (e.g. r^1, r^3) without abs, it violates symmetry.
    # This is hard to check numerically without specific test points.
    # We assume the LLM is guided to produce symmetric forms.
    
    # 4. Asymptotic Behavior
    # As x -> infinity, ΔU -> 0.
    # As r -> infinity, ΔU -> 0.
    # We can check this by evaluating at very large x and r.
    # (This requires passing the function expression, which we don't have here directly, 
    #  but we can assume y_pred covers a wide range or we can pass a separate evaluator function)
    
    # 5. Coefficient Signs (Heuristic)
    # Often, 'a' (amplitude) should be positive.
    p_sign = (coeffs[1] < 0) ? 1.0 : 0.0
    
    total_penalty = p_range + p_sign
    
    return total_penalty
end

end # module
