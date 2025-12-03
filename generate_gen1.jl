using JSON3

models = [
    # 1. Standard Gaussian (Good baseline)
    Dict("id" => 1, "formula" => "a * exp(-b*x) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Standard Gaussian wake model with exponential decay in x and r.", "ep_type" => "Gaussian"),
    
    # 2. Power Law Decay (Good)
    Dict("id" => 2, "formula" => "a * x^(-b) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Power law decay in x, Gaussian in r. Consistent with far wake theory.", "ep_type" => "PowerLaw"),
    
    # 3. Rational Polynomial (Good)
    Dict("id" => 3, "formula" => "a * (1 + b*x)^(-2) * (1 + c*r^2)^(-1)", "num_coeffs" => 3, "reason" => "Rational polynomial decay, similar to Jensen model but smooth.", "ep_type" => "Rational"),
    
    # 4. Nut dependent (Good attempt)
    Dict("id" => 4, "formula" => "a * exp(-b*x) * exp(-c*r^2) * (1 + d*nut)", "num_coeffs" => 4, "reason" => "Added eddy viscosity term to account for turbulence mixing.", "ep_type" => "Physics"),
    
    # 5. Bad Physics (Increasing x) - P1 Violation
    Dict("id" => 5, "formula" => "a * (1 + b*x) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Linear growth in x to test recovery.", "ep_type" => "Experimental"),
    
    # 6. Bad Physics (Negative) - P3 Violation
    Dict("id" => 6, "formula" => "-a * exp(-b*x) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Negative deficit? Just guessing.", "ep_type" => "Random"),
    
    # 7. Asymmetric - P2 Violation
    Dict("id" => 7, "formula" => "a * exp(-b*x) * exp(-c*r)", "num_coeffs" => 3, "reason" => "Exponential in r, not r^2. Might violate symmetry at r=0 cusp.", "ep_type" => "Asymmetric"),
    
    # 8. Complex with K
    Dict("id" => 8, "formula" => "a * k * exp(-b*x) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Using TKE (k) to scale the deficit.", "ep_type" => "Physics"),
    
    # 9. Complex with Omega
    Dict("id" => 9, "formula" => "a * exp(-b*x*omega) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Decay rate depends on omega.", "ep_type" => "Physics"),
    
    # 10. Combined
    Dict("id" => 10, "formula" => "a * (1 + b*x)^(-1.5) * (1 + c*r^2)^(-2) + d*nut", "num_coeffs" => 4, "reason" => "Combination of power law and nut offset.", "ep_type" => "Hybrid"),
    
    # 11-20: Variations
    Dict("id" => 11, "formula" => "a * exp(-b*x^2) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Gaussian in x and r.", "ep_type" => "Gaussian"),
    Dict("id" => 12, "formula" => "a * (x + 1)^(-b) * (r^2 + 1)^(-c)", "num_coeffs" => 3, "reason" => "Shifted power law.", "ep_type" => "PowerLaw"),
    Dict("id" => 13, "formula" => "a * exp(-b*x) * cos(c*r)", "num_coeffs" => 3, "reason" => "Cosine profile in r. P3 violation likely.", "ep_type" => "Trig"),
    Dict("id" => 14, "formula" => "a * tanh(b*x) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Tanh behavior.", "ep_type" => "Sigmoid"),
    Dict("id" => 15, "formula" => "a * exp(-b*x) / (1 + c*r^4)", "num_coeffs" => 3, "reason" => "Quartic denominator in r.", "ep_type" => "Rational"),
    Dict("id" => 16, "formula" => "a * exp(-b*x) * exp(-c*abs(r))", "num_coeffs" => 3, "reason" => "Absolute value for symmetry.", "ep_type" => "Abs"),
    Dict("id" => 17, "formula" => "a * (1 - exp(-b*x)) * exp(-c*r^2)", "num_coeffs" => 3, "reason" => "Recovery form 1-exp.", "ep_type" => "Recovery"),
    Dict("id" => 18, "formula" => "a * x^(-1/3) * exp(-b*r^2)", "num_coeffs" => 2, "reason" => "Fixed power law -1/3.", "ep_type" => "FixedPower"),
    Dict("id" => 19, "formula" => "a * x^(-2/3) * exp(-b*r^2)", "num_coeffs" => 2, "reason" => "Fixed power law -2/3.", "ep_type" => "FixedPower"),
    Dict("id" => 20, "formula" => "a * x^(-1) * exp(-b*r^2)", "num_coeffs" => 2, "reason" => "Fixed power law -1.", "ep_type" => "FixedPower")
]

json_data = Dict("generation" => 1, "models" => models)

open("results/trial_8/models_gen1.json", "w") do io
    JSON3.pretty(io, json_data)
end
