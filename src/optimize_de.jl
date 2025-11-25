module OptimizeDE

using BlackBoxOptim

export optimize_coefficients

"""
    log_uniform_init(lower, upper, num_coeffs, NP)

log-uniform 初期化を行う。
"""
function log_uniform_init(lower, upper, num_coeffs, NP)
    return [exp(rand() * (log(upper) - log(lower)) + log(lower))
            for _ in 1:NP, _ in 1:num_coeffs]
end


"""
    uniform_init(lower, upper, num_coeffs, NP)

一様分布による初期化を行う（負の値を含む場合用）。
"""
function uniform_init(lower, upper, num_coeffs, NP)
    return rand(NP, num_coeffs) .* (upper - lower) .+ lower
end


"""
    optimize_coefficients(ex, x, r, k, omega, nut, deltaU;
                          num_coeffs=4, with_penalty=false,
                          mse_eval=nothing, physical_penalty=nothing,
                          search_range=(1e-4, 1e2))

DE により係数 θ を最適化する。
評価関数は引数として受け取る。
"""
function optimize_coefficients(ex,
                               x, r, k, omega, nut, deltaU;
                               num_coeffs=4,
                               with_penalty=false,
                               mse_eval=nothing,
                               physical_penalty=nothing,
                               search_range=(1e-4, 1e2))

    # 最適化対象の目的関数
    f(θ) = begin
        mse = mse_eval(ex, θ, x, r, k, omega, nut, deltaU)
        if with_penalty
            mse += physical_penalty(ex, θ, x, r, k, omega, nut, deltaU)
        end
        return mse
    end

    # 初期集団
    NP = 30
    lower, upper = search_range
    
    # 範囲に負の値が含まれる場合は一様分布、正のみなら対数一様分布を使用
    if lower < 0
        init_pop = uniform_init(lower, upper, num_coeffs, NP)
    else
        # 安全のため正の最小値を確保
        safe_lower = max(lower, 1e-6)
        init_pop = log_uniform_init(safe_lower, upper, num_coeffs, NP)
    end

    # DE 最適化
    res = bboptimize(
        f;
        SearchRange=search_range,
        NumDimensions=num_coeffs,
        InitPopulation=init_pop,
        PopulationSize=NP,
        MaxSteps=200,
        Method=:de_rand_1_bin,
        F=0.7,
        CR=0.9,
        TraceMode=:silent
    )

    return best_candidate(res), best_fitness(res)
end

end # module

