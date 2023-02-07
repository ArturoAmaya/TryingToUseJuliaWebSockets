using CurricularAnalytics, CurricularAnalyticsDiff, DataFrames

# This is for when prereqs are being added implicitly. We do the best job we can to accomodate
function add_dyno_prereq(new_course::AbstractString, prereq::AbstractString, curr::Curriculum, prereq_chains::DataFrame)
    # look at the dataframe to find prereq
    fil = filter(:"Course ID" => x -> strip(x) == replace(prereq, " " => ""), prereq_chains)
    if size(fil)[1] == 0
        # if there's no match then just add a course with that name and empty characteristics
        new_curr = add_course(prereq, curr, 4.0, Dict(), Dict(new_course => pre))
    else
        # else:
        println(fil)
        if fil[:"Prereq Sequence ID"][end] == missing
            # if the prereq is the beginning of the chain, just add it in with standard units and hook it up
            new_curr = add_course(prereq, curr, 4.0, Dict(), Dict(new_course => pre))
        else
            # for each prereq sequence id:
            for i in range(1, fil[:"Prereq Sequence ID"][end])
                # is one of the courses with that matching id in the curriculum?
                prereq_cluster = filter(:"Prereq Sequence ID" => x -> x == i, fil)
                prereq_names = []
                for row in range(1, size(prereq_cluster)[1])
                    push!(prereq_names, strip(prereq_cluster[row, :"Prereq Subject Code"]) * " " * strip(prereq_cluster[row, "Prereq Course Number"]))
                end
                println(prereq_names)
                # yes:
                # add that course as a prereq
                # no:
                # add that course in recursively with this method
            end
        end
    end
    return new_curr
end


function add_course_inst_web(course_name::AbstractString, credit_hours::Real, prereqs::Dict, dependencies::Dict, curr::Curriculum, nominal_plans::Vector{String})
    try
        results = Dict()
        # skip 0) the curric is passed in
        # get the list of affected plans
        affected = add_course_institutional(course_name, curr, credit_hours, prereqs, dependencies)
        plans = filter(x -> x != "", union!(nominal_plans, affected))
        # for each affected plan:
        for plan in plans
            major = plan[1:4]
            college = plan[5:end]
            curr = read_csv("./files/output/$(major)/$(college).csv")
            if typeof(curr) == DegreePlan
                curr = curr.curriculum
            end
            try
                results[major]
            catch
                results[major] = Dict()
            end
            # add the course in. if all of its prereqs are there already, then it's all good
            # dependencies don't matter unless they happen to coincide with stuff already in the curriculum
            # add an empty course in
            new_curr = add_course(course_name, curr, credit_hours, Dict(), Dict())
            for (preq, type) in prereqs
                if preq in courses_to_course_names(curr.courses)
                    # hook up the prereq
                    println("all good with $preq in $major $college")
                    add_requisite!(course_from_name(preq, new_curr), course_from_name(course_name, new_curr), pre)
                else
                    # add the prereq
                    println("issue with $preq in $major $college -  add it in from the curriculum")

                    # TODO
                end
            end
            # hook up the dependencies if they exist
            for (dep, type) in dependencies
                if dep in courses_to_course_names(curr.courses)
                    # hook up the dep
                    add_requisite!(course_from_name(course_name, new_curr), course_from_name(dep, new_curr), pre)
                end # else do nothing
            end
            ## don't run diff, just check the total credit hours and complexity scores 
            ch_diff = new_curr.credit_hours - curr.credit_hours
            complex_diff = complexity(new_curr)[1] - complexity(curr)[1] # consider using complexity(curr)
            # write the results in 
            results[major][college] = Dict()
            results[major][college]["complexity"] = complex_diff
            results[major][college]["unit change"] = ch_diff
        end
        return results
    catch
    end
end
# 1) find course in condensed and the prereq (ignore this one)
# 2) get list of plans from the what if institutional
# 3) for each plan:
## read the plan csv
## get curric object from it
## remove the prereq
## run diff (maybe not)
## record complexity & unit score differences
function add_prereq_inst_web(course_name::AbstractString, prereq::AbstractString)
    try
        results = Dict()
        # 0) read the condensed
        condensed = read_csv("./files/condensed2.csv")
        # 2) get the list of affected plans
        affected = add_prereq_institutional(condensed, course_name, prereq)
        # 3) for each affected plan:
        plans = filter(x -> x != "", affected)
        for plan in plans
            major = plan[1:4]
            college = plan[5:end]
            curr = read_csv("./files/output/$(major)/$(college).csv")
            if typeof(curr) == DegreePlan
                curr = curr.curriculum
            end
            try
                results[major]
            catch
                results[major] = Dict()
            end
            ## add the prereq
            ## this is harder than the initial version
            ## have to go through each prereq of the prereq you want to add
            ## and add that to the new curriculum 
            try
                # sometimes it'll be super easy
                new_curr = add_prereq(course_name, prereq, curr, pre)
            catch
                # ok so try adding the requisite
                # TODO
            end
            ## don't run diff, just check the total credit hours and complexity scores 
            ch_diff = new_curr.credit_hours - curr.credit_hours
            complex_diff = complexity(new_curr)[1] - complexity(curr)[1] # consider using complexity(curr)
            # write the results in 
            results[major][college] = Dict()
            results[major][college]["complexity"] = complex_diff
            results[major][college]["unit change"] = ch_diff
        end
    catch e
        throw(e)
    end
end

# 1) find course in condensed and the prereq (ignore this one)
# 2) get list of plans from the what if institutional
# 3) for each plan:
## read the plan csv
## get curric object from it
## remove the prereq
## run diff (maybe not)
## record complexity & unit score differences
function remove_prereq_inst_web(target_name::AbstractString, prereq_name::AbstractString)
    try
        results = Dict()
        # 0) read the condensed 
        condensed = read_csv("./files/condensed2.csv")
        # 2) get the list of plans
        affected = delete_prerequisite_institutional(target_name, prereq_name, condensed)
        # 3) for each plan
        plans = filter(x -> x != "", affected)
        println(affected)
        for plan in plans
            major = plan[1:4]
            college = plan[5:end]
            curr = read_csv("./files/output/$(major)/$(college).csv")
            if typeof(curr) == DegreePlan
                curr = curr.curriculum
            end
            try
                results[major]
            catch
                results[major] = Dict()
            end
            ## remove the prereq
            new_curr = remove_prereq(target_name, prereq_name, curr)
            ## don't run diff, just check the total credit hours and complexity scores 
            ch_diff = new_curr.credit_hours - curr.credit_hours
            complex_diff = complexity(new_curr)[1] - complexity(curr)[1] # consider using complexity(curr)
            # write the results in 
            results[major][college] = Dict()
            results[major][college]["complexity"] = complex_diff
            results[major][college]["unit change"] = ch_diff
        end
        return results
    catch e
        throw(e)
    end
end
# 1) find course in condensed 
# 2) get list of plans from the canonical Name
# 3) for each plan:
## read the plan csv
## get curric object from it
## delete the course
## run diff (maybe not)
## record complexity & unit score differences
function remove_course_inst_web(course_name::AbstractString)
    try
        results = Dict()
        # 0) read the condensed
        condensed = read_csv("./files/condensed2.csv")
        # 1)
        course = course_from_name(course_name, condensed)
        # 2) get the list of plans from the condensed course
        plans = filter(x -> x != "", split(course.canonical_name, ","))
        println(plans)
        # 3) for each plan
        for plan in plans
            println(plan)
            ## read the plan csv
            # this is weird and hardcoded, but it should work
            major = plan[1:4]
            college = plan[5:end]
            curr = read_csv("./files/output/$(major)/$(college).csv")
            if typeof(curr) == DegreePlan
                curr = curr.curriculum
            end
            try
                results[major]
            catch
                results[major] = Dict()
            end
            ## delete the course from it
            new_curr = remove_course(course_name, curr)
            ## don't run diff, just check the total credit hours and complexity scores 
            ch_diff = new_curr.credit_hours - curr.credit_hours
            complex_diff = complexity(new_curr)[1] - complexity(curr)[1] # consider using complexity(curr)
            # write the results in 
            results[major][college] = Dict()
            results[major][college]["complexity"] = complex_diff
            results[major][college]["unit change"] = ch_diff
        end
        return results
    catch e
        # dumb, I know
        throw(e)
    end
end

#println("starting")
#condensed = read_csv("./files/condensed2.csv")
#results = add_course_inst_web("MATH 20B.5", 5.0, Dict("CHEM 6A" => pre), Dict("MATH 20C" => pre), condensed, ["BE25RE"])