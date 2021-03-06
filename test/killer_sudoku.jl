function parseKillerJSON(json_sums)
    sums = []
    for s in json_sums
        indices = Tuple[]
        for ind in s["indices"]
            push!(indices, tuple(ind...))
        end

        if haskey(s, "color")
            push!(sums, (result = s["result"], indices = indices, color = s["color"]))
        else
            push!(sums, (result = s["result"], indices = indices, color = "white"))
        end
    end
    return sums
end


@testset "Killer Sudoku" begin

    @testset "Killer Sudoku from wikipedia" begin
        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)

        sums = parseKillerJSON(JSON.parsefile("data/killer_wikipedia"))

        for s in sums
            @constraint(m, sum([x[ind[1], ind[2]] for ind in s.indices]) == s.result)
        end

        # sudoku constraints
        for rc = 1:9
            @constraint(m, x[rc, :] in CS.AllDifferentSet())
            @constraint(m, x[:, rc] in CS.AllDifferentSet())
        end
        for br = 0:2
            for bc = 0:2
                @constraint(
                    m,
                    vec(x[br*3+1:(br+1)*3, bc*3+1:(bc+1)*3]) in CS.AllDifferentSet()
                )
            end
        end

        optimize!(m)

        com = JuMP.backend(m).optimizer.model.inner
        @test com.info.n_constraint_types.alldifferent == 27
        @test com.info.n_constraint_types.equality == length(sums)
        @test length(com.search_space) == 81

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test jump_fulfills_sudoku_constr(JuMP.value.(x))

        for s in sums
            @test s.result == sum(JuMP.value.([x[i[1], i[2]] for i in s.indices]))
        end
    end

    @testset "Killer Sudoku from wikipedia with normal rules" begin
        m = Model(CSJuMPTestSolver())
        @variable(m, 1 <= x[1:9, 1:9] <= 9, Int)

        sums = parseKillerJSON(JSON.parsefile("data/killer_wikipedia"))

        for s in sums
            @constraint(m, sum([x[ind[1], ind[2]] for ind in s.indices]) == s.result)
            @constraint(
                m,
                [x[ind[1], ind[2]] for ind in s.indices] in CS.AllDifferentSet()
            )
        end

        # sudoku constraints
        for rc = 1:9
            @constraint(m, x[rc, :] in CS.AllDifferentSet())
            @constraint(m, x[:, rc] in CS.AllDifferentSet())
        end
        for br = 0:2
            for bc = 0:2
                @constraint(
                    m,
                    vec(x[br*3+1:(br+1)*3, bc*3+1:(bc+1)*3]) in CS.AllDifferentSet()
                )
            end
        end

        optimize!(m)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test jump_fulfills_sudoku_constr(JuMP.value.(x))
        @test JuMP.solve_time(m) >= 0

        for s in sums
            @test s.result == sum(JuMP.value.([x[i[1], i[2]] for i in s.indices]))
        end
    end

    @testset "Killer Sudoku niallsudoku_5500 with coefficients" begin
        com = CS.ConstraintSolverModel()

        grid = zeros(Int, (9, 9))

        com_grid = Array{CS.Variable,2}(undef, 9, 9)
        for (ind, val) in enumerate(grid)
            com_grid[ind] = CS.add_var!(com, 1, 9)
        end

        sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5500"))

        # the upper left sum constraint is x+y+z = 10 and the solution is 2+1+7
        # here I change it to 5*x+7*y+z = 24
        CS.add_constraint!(
            com,
            5 * com_grid[CartesianIndex(1, 1)] +
            7 * com_grid[CartesianIndex(2, 1)] +
            com_grid[CartesianIndex(2, 2)] == 24,
        )

        for s in sums[2:end]
            CS.add_constraint!(
                com,
                sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result,
            )
        end

        add_sudoku_constr!(com, com_grid)

        options = Dict{Symbol,Any}()
        options[:keep_logs] = true
        options[:traverse_strategy] = :DFS

        options = CS.combine_options(options)

        @test CS.solve!(com, options) == :Solved
        logs_1 = CS.get_logs(com)
        info_1 = com.info
        @test fulfills_sudoku_constr(com_grid)
        @test 5 * CS.value(com_grid[CartesianIndex(1, 1)]) +
        7 * CS.value(com_grid[CartesianIndex(2, 1)]) +
        CS.value(com_grid[CartesianIndex(2, 2)]) == 24
        for s in sums[2:end]
            @test s.result ==
                  sum([CS.value(com_grid[CartesianIndex(i)]) for i in s.indices])
        end
        @test com.solve_time >= 0

        # test if deterministic by running it again
        com = CS.ConstraintSolverModel()

        grid = zeros(Int, (9, 9))

        com_grid = Array{CS.Variable,2}(undef, 9, 9)
        for (ind, val) in enumerate(grid)
            com_grid[ind] = CS.add_var!(com, 1, 9)
        end

        sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5500"))

        # the upper left sum constraint is x+y+z = 10 and the solution is 2+1+7
        # here I change it to 5*x+7*y+z = 24
        CS.add_constraint!(
            com,
            5 * com_grid[CartesianIndex(1, 1)] +
            7 * com_grid[CartesianIndex(2, 1)] +
            com_grid[CartesianIndex(2, 2)] == 24,
        )

        for s in sums[2:end]
            CS.add_constraint!(
                com,
                sum([com_grid[CartesianIndex(ind)] for ind in s.indices]) == s.result,
            )
        end

        add_sudoku_constr!(com, com_grid)


        options = Dict{Symbol,Any}()
        options[:keep_logs] = true
        options[:logging] = []

        options = CS.combine_options(options)
        status = CS.solve!(com, options)

        logs_2 = CS.get_logs(com)
        info_2 = com.info
        @test info_1.pre_backtrack_calls == info_2.pre_backtrack_calls
        @test info_1.backtrack_fixes == info_2.backtrack_fixes
        @test info_1.in_backtrack_calls == info_2.in_backtrack_calls
        @test info_1.backtrack_reverses == info_2.backtrack_reverses
        @test CS.same_logs(logs_1[:tree], logs_2[:tree])
    end

    function killer_negative(;reverse_order=false)
        m = Model(optimizer_with_attributes(
            CS.Optimizer,
            "keep_logs" => true,
            "logging" => [],
        ))

        @variable(m, -9 <= com_grid[1:9, 1:9] <= -1, Int)

        sums = parseKillerJSON(JSON.parsefile("data/killer_niallsudoku_5503"))
        if reverse_order
            reverse!(sums)
        end

        for s in sums
            @constraint(m, sum([com_grid[ind...] for ind in s.indices]) == -s.result)
        end

        jump_add_sudoku_constr!(m, com_grid)
        optimize!(m)

        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test jump_fulfills_sudoku_constr(com_grid)
        for s in sums
            @test -s.result == sum([JuMP.value(com_grid[i...]) for i in s.indices])
        end
        return JuMP.backend(m).optimizer.model.inner
    end

    @testset "Killer Sudoku niallsudoku_5503 with negative coefficients and -9 to -1" begin
        com1 = killer_negative()
        # the constraint order should not effect anything
        com2 = killer_negative(;reverse_order=true)
        info_1 = com1.info
        info_2 = com2.info
        @test info_1.pre_backtrack_calls == info_2.pre_backtrack_calls
        @test info_1.backtrack_fixes == info_2.backtrack_fixes
        @test info_1.in_backtrack_calls == info_2.in_backtrack_calls
        @test info_1.backtrack_reverses == info_2.backtrack_reverses
        logs_1 = CS.get_logs(com1)
        logs_2 = CS.get_logs(com2)
        @test CS.same_logs(logs_1[:tree], logs_2[:tree])
    end

end
