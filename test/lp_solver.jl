@testset "LP Solver" begin
    @testset "Issue 83 TimeLimit" begin
        glpk_optimizer = optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.OFF)
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "lp_optimizer" => glpk_optimizer,
            "logging" => [],
            "time_limit" => 0.01
        ))

        # Variables
        @variable(model, inclusion[h = 1:3], Bin)
        @variable(model, 0 <= allocations[h = 1:3, a = 1:3] <= 1, Int)
        @variable(model, 0 <= days[h = 1:3, a = 1:3] <= 5, Int)

        # Constraints
        @constraint(
            model,
            must_include[h = 1:3],
            sum(allocations[h, a] for a = 1:3) <= inclusion[h]
        )
        # at least n
        @constraint(model, min_hospitals, sum(inclusion[h] for h = 1:3) >= 3)
        # every h must be allocated at most one a
        @constraint(model, must_visit[h = 1:3], sum(allocations[h, a] for a = 1:3) <= 1)
        # every allocated h must have fewer than 5 days of visits per week
        @constraint(
            model,
            max_visits[h = 1:3],
            sum(days[h, a] for a = 1:3) <= 5 * inclusion[h]
        )

        @objective(model, Max, sum(days[h, a] * 5 for h = 1:3, a = 1:3))
        optimize!(model)
        @test JuMP.termination_status(model) == MOI.TIME_LIMIT
    end

    @testset "Issue 83 max_bt_steps" begin
        glpk_optimizer = optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.OFF)
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "lp_optimizer" => glpk_optimizer,
            "logging" => [],
            "max_bt_steps" => 2
        ))

        # Variables
        @variable(model, inclusion[h = 1:3], Bin)
        @variable(model, 0 <= allocations[h = 1:3, a = 1:3] <= 1, Int)
        @variable(model, 0 <= days[h = 1:3, a = 1:3] <= 5, Int)

        # Constraints
        @constraint(
            model,
            must_include[h = 1:3],
            sum(allocations[h, a] for a = 1:3) <= inclusion[h]
        )
        # at least n
        @constraint(model, min_hospitals, sum(inclusion[h] for h = 1:3) >= 3)
        # every h must be allocated at most one a
        @constraint(model, must_visit[h = 1:3], sum(allocations[h, a] for a = 1:3) <= 1)
        # every allocated h must have fewer than 5 days of visits per week
        @constraint(
            model,
            max_visits[h = 1:3],
            sum(days[h, a] for a = 1:3) <= 5 * inclusion[h]
        )

        @objective(model, Max, sum(days[h, a] * 5 for h = 1:3, a = 1:3))
        optimize!(model)
        @test JuMP.termination_status(model) == MOI.OTHER_LIMIT
    end


    @testset "Issue 83" begin
        glpk_optimizer = optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.OFF)
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "lp_optimizer" => glpk_optimizer,
            "logging" => [],
        ))

        # Variables
        @variable(model, inclusion[h = 1:3], Bin)
        @variable(model, 0 <= allocations[h = 1:3, a = 1:3] <= 1, Int)
        @variable(model, 0 <= days[h = 1:3, a = 1:3] <= 5, Int)

        # Constraints
        @constraint(
            model,
            must_include[h = 1:3],
            sum(allocations[h, a] for a = 1:3) <= inclusion[h]
        )
        # at least n
        @constraint(model, min_hospitals, sum(inclusion[h] for h = 1:3) >= 3)
        # every h must be allocated at most one a
        @constraint(model, must_visit[h = 1:3], sum(allocations[h, a] for a = 1:3) <= 1)
        # every allocated h must have fewer than 5 days of visits per week
        @constraint(
            model,
            max_visits[h = 1:3],
            sum(days[h, a] for a = 1:3) <= 5 * inclusion[h]
        )

        @objective(model, Max, sum(days[h, a] * 5 for h = 1:3, a = 1:3))
        optimize!(model)
        @test JuMP.objective_value(model) ≈ 75
    end

    @testset "Combine lp with all different + not equal" begin
        cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "lp_optimizer" => cbc_optimizer,
            "logging" => [],
            "traverse_strategy" => :DBFS
        ))

        # Variables
        @variable(model, 1 <= x[1:10] <= 15, Int)

        # Constraints
        @constraint(model, sum(x[1:5]) >= 10)
        @constraint(model, sum(x[6:10]) <= 15)
        # disallow x[1] = 11 and x[2] == 12
        @constraint(model, 1.5*x[1]+2*x[2] != 40.5)
        @constraint(model, x in CS.AllDifferentSet())

        @objective(model, Max, sum(x))
        optimize!(model)
        # possible solution 11+12+13+14+15  + 1+2+3+4+5
        # only works fast if the all different bound works 
        @test JuMP.objective_value(model) ≈ 80
        @test sum(JuMP.value.(x[6:10])) ≈ 15
        @test !(1.5*JuMP.value(x[1]) + 2*JuMP.value(x[2]) ≈ 40.5)
    end

    @testset "Combine lp with all different + not equal + DFS" begin
        cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "lp_optimizer" => cbc_optimizer,
            "logging" => [],
            "traverse_strategy" => :DFS,
            "branch_split" => :Biggest
        ))

        # Variables
        @variable(model, 1 <= x[1:10] <= 15, Int)
        
        # Constraints
        @constraint(model, sum(x[1:5]) >= 10)
        @constraint(model, sum(x[6:10]) <= 15)
        # disallow x[1] = 11 and x[2] == 12
        @constraint(model, 1.5*x[1]+2*x[2] != 40.5)
        @constraint(model, x in CS.AllDifferentSet())
       
        @objective(model, Max, sum(x))
        optimize!(model)
        # possible solution 11+12+13+14+15  + 1+2+3+4+5
        # only works fast if the all different bound works 
        @test JuMP.objective_value(model) ≈ 80
        @test sum(JuMP.value.(x[6:10])) ≈ 15
        @test !(1.5*JuMP.value(x[1]) + 2*JuMP.value(x[2]) ≈ 40.5)
    end

    @testset "Combine lp with all different + not equal + DFS + Split Half" begin
        cbc_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        model = Model(optimizer_with_attributes(
            CS.Optimizer,
            "lp_optimizer" => cbc_optimizer,
            # "logging" => [],
            "traverse_strategy" => :DFS,
            "branch_split" => :InHalf
        ))

        # Variables
        @variable(model, 1 <= x[1:10] <= 15, Int)
        
        # Constraints
        @constraint(model, sum(x[1:5]) >= 10)
        @constraint(model, sum(x[6:10]) <= 15)
        # disallow x[1] = 11 and x[2] == 12
        @constraint(model, 1.5*x[1]+2*x[2] != 40.5)
        @constraint(model, x in CS.AllDifferentSet())
       
        @objective(model, Max, sum(x))
        optimize!(model)
        # possible solution 11+12+13+14+15  + 1+2+3+4+5
        # only works fast if the all different bound works 
        @test JuMP.objective_value(model) ≈ 80
        @test sum(JuMP.value.(x[6:10])) ≈ 15
        @test !(1.5*JuMP.value(x[1]) + 2*JuMP.value(x[2]) ≈ 40.5)
    end
end
