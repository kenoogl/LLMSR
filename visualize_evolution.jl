#!/usr/bin/env julia

"""
Visualize Evolution Progress

進化計算の履歴を可視化

使用方法:
    julia --project=. visualize_evolution.jl
"""

using JSON3
using Statistics
using Plots
using Printf

"""
    load_history(filepath::String)

履歴ファイル（JSONL）を読み込む
"""
function load_history(filepath::String="results/history.jsonl")
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
    plot_evolution_curve(history::Vector)

進化曲線をプロット（世代ごとのベストスコア推移）
"""
function plot_evolution_curve(history::Vector, output_dir::String="results/plots")
    generations = [h.generation for h in history]
    best_scores = [h.best_score for h in history]
    mean_scores = [h.mean_score for h in history]
    
    p = plot(
        generations, 
        best_scores,
        label="Best Score",
        xlabel="Generation",
        ylabel="MSE Score",
        title="Evolution of Wake Models",
        marker=:circle,
        linewidth=2,
        legend=:topright,
        grid=true,
        size=(800, 500)
    )
    
    plot!(p, generations, mean_scores,
          label="Mean Score",
          marker=:square,
          linewidth=2,
          linestyle=:dash)
    
    # 保存
    mkpath(output_dir)
    savefig(p, joinpath(output_dir, "evolution_curve.png"))
    @info "Evolution curve saved to: $(joinpath(output_dir, "evolution_curve.png"))"
    
    return p
end


"""
    plot_score_distribution(history::Vector)

各世代のスコア分布をboxplotで表示
"""
function plot_score_distribution(history::Vector, output_dir::String="results/plots")
    # 各世代のスコアを取得
    all_scores = []
    labels = String[]
    
    for h in history
        scores = [m.score for m in h.all_models]
        append!(all_scores, scores)
        append!(labels, fill("Gen $(h.generation)", length(scores)))
    end
    
    p = boxplot(
        labels,
        all_scores,
        xlabel="Generation",
        ylabel="MSE Score",
        title="Score Distribution by Generation",
        legend=false,
        grid=true,
        size=(800, 500)
    )
    
    # 保存
    savefig(p, joinpath(output_dir, "score_distribution.png"))
    @info "Score distribution saved to: $(joinpath(output_dir, "score_distribution.png"))"
    
    return p
end


"""
    print_summary(history::Vector)

進化の概要をテキストで出力
"""
function print_summary(history::Vector, output_file::String="results/plots/evolution_summary.txt")
    io_buffer = IOBuffer()
    
    println(io_buffer, "="^70)
    println(io_buffer, "Evolution Summary")
    println(io_buffer, "="^70)
    println(io_buffer, "")
    println(io_buffer, "Total Generations: $(length(history))")
    println(io_buffer, "")
    
    # 各世代のサマリー
    for h in history
        println(io_buffer, "-"^70)
        println(io_buffer, "Generation $(h.generation)")
        println(io_buffer, "-"^70)
        @printf(io_buffer, "  Best Score:   %.6f\n", h.best_score)
        @printf(io_buffer, "  Mean Score:   %.6f\n", h.mean_score)
        println(io_buffer, "  Best Model:   $(h.best_model.formula)")
        println(io_buffer, "  Coefficients: $(round.(h.best_model.coefficients, digits=4))")
        if haskey(h.best_model, :reason) && !isempty(h.best_model.reason)
            println(io_buffer, "  Reason:       $(h.best_model.reason)")
        end
        println(io_buffer, "")
    end
    
    # 最終ベストモデル
    best_gen = argmin([h.best_score for h in history])
    best = history[best_gen]
    
    println(io_buffer, "="^70)
    println(io_buffer, "🏆 Overall Best Model (Found in Generation $(best.generation))")
    println(io_buffer, "="^70)
    @printf(io_buffer, "Score:        %.6f\n", best.best_score)
    println(io_buffer, "Formula:      $(best.best_model.formula)")
    println(io_buffer, "Coefficients: $(round.(best.best_model.coefficients, digits=4))")
    if haskey(best.best_model, :reason) && !isempty(best.best_model.reason)
        println(io_buffer, "Reason:       $(best.best_model.reason)")
    end
    println(io_buffer, "")
    
    # 改善率
    if length(history) > 1
        initial_score = history[1].best_score
        final_score = best.best_score
        improvement = (initial_score - final_score) / initial_score * 100
        @printf(io_buffer, "Improvement:  %.2f%%\n", improvement)
    end
    
    summary_text = String(take!(io_buffer))
    
    # コンソールに出力
    println(summary_text)
    
    # ファイルに保存
    mkpath(dirname(output_file))
    write(output_file, summary_text)
    @info "Summary saved to: $output_file"
    
    return summary_text
end


"""
    analyze_ep_strategy(history::Vector)

EP戦略の使用頻度と効果を分析
"""
function analyze_ep_strategy(history::Vector)
    println("\n" * "="^70)
    println("EP Strategy Analysis")
    println("n="^70)
    
    ep_counts = Dict{String, Int}()
    ep_scores = Dict{String, Vector{Float64}}()
    
    for h in history
        for m in h.all_models
            if haskey(m, :ep_type) && !isempty(m.ep_type)
                ep = m.ep_type
                
                # カウント
                ep_counts[ep] = get(ep_counts, ep, 0) + 1
                
                # スコア記録
                if !haskey(ep_scores, ep)
                    ep_scores[ep] = Float64[]
                end
                push!(ep_scores[ep], m.score)
            end
        end
    end
    
    # 結果表示
    for (ep, count) in sort(collect(ep_counts), by=x->x[1])
        mean_score = mean(ep_scores[ep])
        @printf "  %s: %3d models, Mean Score: %.6f\n" ep count mean_score
    end
    
    println()
end


# メイン処理
function main()
    println("\n" * "="^70)
    println("📊 Visualizing Evolution Progress")
    println("="^70)
    
    # 履歴読み込み
    history = load_history()
    println("\n✓ Loaded history: $(length(history)) generations")
    
    if isempty(history)
        println("⚠️  No history data available yet")
        return
    end
    
    # 進化曲線
    println("\n📈 Plotting evolution curve...")
    plot_evolution_curve(history)
    
    # スコア分布
    if length(history) >= 2
        println("📊 Plotting score distribution...")
        plot_score_distribution(history)
    end
    
    # サマリー出力
    println("\n📝 Generating summary...")
    print_summary(history)
    
    # EP戦略分析
    analyze_ep_strategy(history)
    
    println("="^70)
    println("✅ Visualization Complete!")
    println("="^70)
    println("\nOutput files:")
    println("  - results/plots/evolution_curve.png")
    println("  - results/plots/score_distribution.png")
    println("  - results/plots/evolution_summary.txt")
    println()
end

# 実行
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
