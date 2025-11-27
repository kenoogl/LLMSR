using Test
include("src/evolution_utils.jl")
using .EvolutionUtils

@testset "Diversity-Aware Elitism Tests" begin
    # モックモデルの作成
    models = [
        (id=1, model="a * exp(-b*x)", score=0.1, coeffs=[], reason="", ep_type=""),
        (id=2, model="a * exp(-b*x)", score=0.11, coeffs=[], reason="", ep_type=""), # ID1と酷似
        (id=3, model="a * x^(-b)", score=0.12, coeffs=[], reason="", ep_type=""),    # 構造が違う
        (id=4, model="a * exp(-b*x) + c", score=0.13, coeffs=[], reason="", ep_type=""), # ID1と少し似ている
        (id=5, model="a * (1+x)^(-b)", score=0.14, coeffs=[], reason="", ep_type="") # 構造が違う
    ]

    # ケース1: 上位2つを選ぶ（閾値高め = 厳しく判定）
    # ID1は確定。ID2はID1と似すぎている(類似度ほぼ1.0)のでスキップされるはず。
    # ID3はID1と違うので選ばれるはず。
    elites_strict = select_diverse_elites(models, 2; similarity_threshold=0.8)
    @test length(elites_strict) == 2
    @test elites_strict[1].id == 1
    @test elites_strict[2].id == 3
    println("Strict selection (Top 2): IDs ", [m.id for m in elites_strict])

    # ケース2: 上位3つを選ぶ
    # ID1, ID3, ID5 が選ばれることを期待（ID4はID1に近いが、ID2よりは遠いかも？計算次第）
    elites_3 = select_diverse_elites(models, 3; similarity_threshold=0.8)
    @test length(elites_3) == 3
    @test elites_3[1].id == 1
    @test elites_3[2].id == 3
    # 3つ目はID5かID4だが、ID4 "a*exp(-b*x)+c" vs ID1 "a*exp(-b*x)"
    # 距離は "+c" の分だけある。
    println("Strict selection (Top 3): IDs ", [m.id for m in elites_3])

    # ケース3: 閾値を緩める（何でも通す）
    elites_loose = select_diverse_elites(models, 2; similarity_threshold=1.0)
    @test elites_loose[1].id == 1
    @test elites_loose[2].id == 2 # ID2が選ばれるはず
    println("Loose selection (Top 2): IDs ", [m.id for m in elites_loose])
    
    # ケース4: モデル数が要求より少ない場合
    small_models = models[1:1]
    elites_small = select_diverse_elites(small_models, 2)
    @test length(elites_small) == 1
    @test elites_small[1].id == 1
end
