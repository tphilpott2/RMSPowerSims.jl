"""
    first_order_nonwindup(y, dy, u_in, T, y_min, y_max)

Implements a first order non-windup block.

Implementation details are derived from "Recommended Practice for Excitation System Models", IEEE Std 421.5, 2016."

# Arguments
- `y`: Output of the block.
- `dy`: Derivative of the output of the block.
- `u_in`: Input to the block.
- `T`: Time constant of the block.
- `y_min`: Minimum value of the output.
- `y_max`: Maximum value of the output.

# Equations

``dy - \\frac{u_{in} - y}{T}``

``y_{min} ≤ y ≤ y_{max}``
"""
function first_order_nonwindup(y, dy, u_in, T, y_min, y_max)
    if y >= y_max # at max saturation
        if u_in <= y # needed to return from saturated state
            derivative_equation = dy - (u_in - y) / T
        else
            derivative_equation = dy
        end
    elseif y <= y_min # at min saturation
        if u_in <= y # needed to return from saturated state
            derivative_equation = dy - (u_in - y) / T
        else
            derivative_equation = dy
        end
    else # not saturated
        derivative_equation = dy - (u_in - y) / T
    end
    return derivative_equation
end