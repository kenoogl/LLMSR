module Evaluator

using Statistics
using Printf

export parse_model_expression,
       eval_model,
       mse_eval,
       physical_penalty

"""
    parse_model_expression(model_str::String)

Julia構文のモデル式（構造式）を Expr に変換する。
"""
function parse_model_expression(model_str::String)
    try
        return Meta.parse(model_str)
    catch e
        @error "Expression parse error" e
        return nothing
    end
end


"""
    eval_model(ex, θ, x, r, k, omega, nut)

構造式 ex と係数 θ から ΔU_model を評価する。
θ = [a,b,c,d,e,...] に対応。
"""
function eval_model(ex::Expr, θ, x, r, k, omega, nut)

    # 係数辞書
    localvars = Dict{Symbol,Any}()
    coeff_names = [:a, :b, :c, :d, :e, :f, :g, :h, :i]

    for (i, nm) in enumerate(coeff_names)
        if i > length(θ)
            break
        end
        localvars[nm] = θ[i]
    end

    # 変数をセット
    localvars[:x] = x
    localvars[:r] = r
    localvars[:k] = k
    localvars[:omega] = omega
    localvars[:nut] = nut

    # 評価
    try
        return eval(Expr(:let,
            [:( $(k) = $(v) ) for (k,v) in localvars]...,
            ex))
    catch e
        @error "eval_model failed" e
        return fill(1e9, length(x))  # 失敗したら巨大値
    end
end


"""
    mse_eval(ex, θ, x, r, k, omega, nut, deltaU)

ΔU_model と ΔU_data の MSE を評価。
"""
function mse_eval(ex, θ, x, r, k, omega, nut, deltaU)
    ŷ = eval_model(ex, θ, x, r, k, omega, nut)
    return mean((ŷ .- deltaU).^2)
end


"""
    physical_penalty(ex, θ, ...)

P1〜P4 のペナルティを計算。
必要に応じて改良可能。
"""
function physical_penalty(ex, θ, x, r, k, omega, nut, deltaU)

    ŷ = eval_model(ex, θ, x, r, k, omega, nut)

    # P1: x方向の減衰性違反（粗い例）
    P1 = mean(max.(diff(ŷ), 0))  # ΔU が増加していたらペナルティ

    # P2: r方向対称性
    # r>0 と r<0 の差を簡易評価
    P2 = mean(abs.(ŷ[r .> 0] .- ŷ[r .< 0]))  # 厳密ではないが概念的

    # P3: ΔU の非物理範囲
    P3 = mean((ŷ .< 0) .* abs.(ŷ) .+ (ŷ .> 1) .* abs.(ŷ .- 1))

    # P4: nutとの整合（nut 大→拡散大）
    # nut が大きいのに ΔU が急激に変化 → ペナルティ
    P4 = mean(abs.(nut .* diff(ŷ)))

    # 重み
    λ1, λ2, λ3, λ4 = 1.0, 0.5, 2.0, 0.2

    P = λ1*P1 + λ2*P2 + λ3*P3 + λ4*P4
    return P
end

end # module

