function plot_res(net::Dict, elm::String, ind, var::String; kwargs...)
    t = net["t_vec"]
    x = net[elm]["$ind"]["sol"][var]
    pl = plot(t, x, lw=2, frame=:box, label="$var$ind"; kwargs...)
    return pl
end

function plot_res!(net::Dict, elm::String, ind, var::String; kwargs...)
    t = net["t_vec"]
    x = net[elm]["$ind"]["sol"][var]
    plot!(t, x, lw=2, frame=:box, label="$var$ind"; kwargs...)
end

# Plot deviation of variable from initial conditions
function plot_res_dev_init(net::Dict, elm::String, ind, var::String; kwargs...)
    t = net["t_vec"]
    x = net[elm]["$ind"]["sol"][var]
    pl = plot(t, x .- x[1], lw=2, frame=:box, label="$var$ind"; kwargs...)
    return pl
end
function plot_res_dev_init!(net::Dict, elm::String, ind, var::String; kwargs...)
    t = net["t_vec"]
    x = net[elm]["$ind"]["sol"][var]
    plot!(t, x .- x[1], lw=2, frame=:box, label="$var$ind"; kwargs...)
end

# Plot all results for a given element
function plot_all(net::Dict, elm, var; kwargs...)
    pl = plot()
    for (k, v) in net[elm]
        plot_res!(net, elm, k, var; kwargs...)
    end
    return pl
end
function plot_all!(net::Dict, elm, var; kwargs...)
    for (k, v) in net[elm]
        plot_res!(net, elm, k, var; kwargs...)
    end
    return pl
end
function plot_all_dev_init(net::Dict, elm::String, var::String; kwargs...)
    pl = plot()
    for (k, v) in net[elm]
        plot_res_dev_init!(net, elm, k, var; kwargs...)
    end
    return pl
end
function plot_all_dev_init!(net::Dict, elm::String, var::String; kwargs...)
    for (k, v) in net[elm]
        plot_res_dev_init!(net, elm, k, var; kwargs...)
    end
end
