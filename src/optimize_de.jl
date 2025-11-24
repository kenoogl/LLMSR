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
    optimize_coefficients(ex, x, r, k, omega, nut, deltaU;
                          num_coeffs=4, with_penalty=false,
                          mse_eval=nothing, physical_penalty=nothing)

DE により係数 θ を最適化する。
評価関数は引数として受け取る。
"""
function optimize_coefficients(ex,
                               x, r, k, omega, nut, deltaU;
                               num_coeffs=4,
                               with_penalty=false,
                               mse_eval=nothing,
                               physical_penalty=nothing)

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
    init_pop = log_uniform_init(1e-4, 1e2, num_coeffs, NP)

    # DE 最適化
    res = bboptimize(
        f;
        SearchRange=(1e-4, 1e2),
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

