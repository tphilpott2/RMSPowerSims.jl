string_to_component_model_type = Dict(
    "SixthOrderModel" => SixthOrderModel,
    "ConstantExcitation" => ConstantExcitation,
    "ConstantMechanicalPower" => ConstantMechanicalPower,
    "TGOV1" => TGOV1,
    "IEEET1" => IEEET1,
    "ZIPLoad" => ZIPLoad,
)

"""
    parse_network_json(file_path)

Parse a network JSON file to a format suitable for simulation with RMSPowerSims.

# Arguments
- file_path: Path to the network JSON file.

# Note
- JSON does not support the custom types used in RMSPowerSims. This function converts the strings in the JSON to the corresponding types. This will only work for the types defined in the string_to_component_model_type dictionary. If you have custom types, you will need to modify this dictionary.
"""
function parse_network_json(file_path)
    # read JSON
    open(file_path, "r") do file
        json_str = read(file, String)
        net = JSON.parse(json_str)

        # convert strings to component model types
        for (g, gen) in net["gen"]
            if haskey(gen, "dynamic_model")
                if haskey(gen["dynamic_model"], "model_type")
                    gen["dynamic_model"]["model_type"] = string_to_component_model_type[gen["dynamic_model"]["model_type"]]
                end
                if haskey(gen["dynamic_model"], "controllers")
                    # Convert from strings to controller models
                    for (c, controller) in gen["dynamic_model"]["controllers"]
                        if haskey(controller, "model_type")
                            controller["model_type"] = string_to_component_model_type[controller["model_type"]]
                        end
                    end
                end
            end
        end
        for (l, load) in net["load"]
            if haskey(load, "dynamic_model")
                if haskey(load["dynamic_model"], "model_type")
                    load["dynamic_model"]["model_type"] = string_to_component_model_type[load["dynamic_model"]["model_type"]]
                end
            end
        end
        return net
    end
end

"""
    save_network_json(net, file_path)

Save a network to a JSON file.

# Arguments
- net: Network data dictionary.
- file_path: Path to save the network JSON file.
"""
function save_network_json(net, file_path)
    json_str = JSON.json(net)
    open(file_path, "w") do file
        write(file, json_str)
    end
end