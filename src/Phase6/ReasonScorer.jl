module ReasonScorer

export score_reason

"""
    score_reason(reason::String)

Evaluates the quality of the 'reason' provided by the LLM.
Returns a score between 0.0 (poor) and 1.0 (excellent).
"""
function score_reason(reason::String)
    score = 0.5 # Base score
    
    reason_lower = lowercase(reason)
    
    # 1. Keywords Check (Physics terms)
    keywords = ["turbulence", "viscosity", "decay", "gaussian", "profile", "momentum", "energy", "wake", "recovery", "expansion"]
    keyword_count = sum(occursin(k, reason_lower) for k in keywords)
    
    if keyword_count >= 3
        score += 0.2
    elseif keyword_count >= 1
        score += 0.1
    end
    
    # 2. Specificity Check
    # Penalize vague terms like "adjusted", "optimized", "better" without context
    vague_terms = ["adjusted", "tweaked", "random", "guess"]
    if any(occursin(v, reason_lower) for v in vague_terms)
        score -= 0.1
    end
    
    # 3. Length Check (Too short is bad, too long is okay)
    if length(reason) < 20
        score -= 0.2
    end
    
    # Clamp score
    return clamp(score, 0.1, 1.0)
end

end # module
