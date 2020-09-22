module Microprediction

using HTTP
using JSON
using TimeSeries


struct Config
    "The base URL of the microprediction.org API"
    baseUrl::String
    "The failover URL of the microprediction.org API"
    failoverBaseUrl::String
    "The number of predictions that should be returned from the predictive distribution."
    numPredictions::Int64
    "An array of delays for forecasts"
    delays::Array{Int64}
    "The minimum balance of a key before it is considered bankrupt"
    minBalance::Float64
    "The minimum length of a key if it is going to write data"
    minLen::Int64
    "The write key to use"
    writeKey::Union{Nothing,String}

    "Construct a new Config without a write key"
    function Config()
        Config(nothing)
    end

    "Construct a new Config using a write_key"
    function Config(write_key)
        baseUrl = "http://api.microprediction.org"
        failoverBaseUrl = "http://stableapi.microprediction.org"

        configUrl = "http://config.microprediction.org/config.json"

        # Get the rest of the config.
        r = HTTP.request("GET", configUrl)
        configData = JSON.parse(String(r.body))

        delays = configData["delays"]
        minBalance = configData["min_balance"]
        minLen = configData["min_len"]
        numPredictions = configData["num_predictions"]

        new(baseUrl, failoverBaseUrl, numPredictions, delays, minBalance, minLen, write_key)
    end
end

"""
    get_current_value(config, stream_name)

Return the latest value from the specified stream. If the stream is
unknown return nothing.

Stream name can be the live data name, or example cop.json or it
can be prefixed such as, lagged_values::cop.json or delayed::70::cop.json

"""
function get_current_value(config::Config, stream_name::String)::Union{Float64,Nothing}
    r = HTTP.request("GET", "$(config.baseUrl)/live/$(stream_name)");
    value = JSON.parse(String(r.body))
    if value == nothing
        return value
    end

    return parse(Float64, value)
end

"""
    get_leaderboard(config, stream_name, delay)

Return the leaderboard for the stream with the specified delay.  If the
stream is unknown return nothing

"""
function get_leaderboard(config::Config, stream_name::String, delay::Number)::Union{Nothing,Dict{String,Float64}}
    r = HTTP.request("GET", "$(config.baseUrl)/leaderboards/$(stream_name)"; query=Dict("delay" => delay))
    return JSON.parse(String(r.body))
end


"""
    get_overall(config)

Return the overall leaderboard.

"""
function get_overall(config::Config)::Dict{String,Float64}
    r = HTTP.request("GET", "$(config.baseUrl)/overall")
    return JSON.parse(String(r.body))
end


"""
    get_sponsors(config)

Return the sponsors of streams.

"""
function get_sponsors(config::Config)::Dict{String,String}
    r = HTTP.request("GET", "$(config.baseUrl)/sponsors/")
    return JSON.parse(String(r.body))
end

"""
    get_budgets(config)

Return the budgets of existing streams.

"""
function get_budgets(config::Config)::Dict{String,Float64}
    r = HTTP.request("GET", "$(config.baseUrl)/budgets/")
    return JSON.parse(String(r.body))
end


"""
    get_summary(config, stream_name)

Return the summary information about a stream

"""
function get_summary(config::Config, stream_name::String)
    r = HTTP.request("GET", "$(config.baseUrl)/live/summary::$(stream_name)")
    data = JSON.parse(String(r.body))

    return data
end

"""
    get_lagged(config, stream_name)

Return lagged time and values of a time series. The newest times are placed at 
the start of the result array.  The values are a Float64 of Unix epoch times.

"""
function get_lagged(config::Config, stream_name::String)::TimeArray{Float64,1,DateTime,Array{Float64,1}}
    r = HTTP.request("GET", "$(config.baseUrl)/live/lagged::$(stream_name)")
    data = JSON.parse(String(r.body))
    live_data = permutedims(reshape(collect(Iterators.Flatten(data)), (2, :)))
    live_data = live_data[:, sortperm(live_data[:, 1])]
    live_dates = Dates.unix2datetime.(live_data[:, 1])
    live_values = live_data[:, 2]
    TimeArray(live_dates, live_values)
end



"""
    get_delayed_value(config, stream_name[, delay])

Return a quarentined value from a stream.

"""
function get_delayed_value(config::Config, stream_name::String, delay::Number=config.delays[1])::Float64
    r = HTTP.request("GET", "$(config.baseUrl)/live/delayed::$(delay)::$(stream_name)")
    JSON.parse(String(r.body))
end

"""
    write_to_stream(config, stream_name, value)

Add a value to a stream, if the stream does not exist it is created.

"""
function write_to_stream(config::Config, stream_name::String, value::Number)
    r = HTTP.request("PUT", "$(config.baseUrl)/live/$(stream_name)";
    query=Dict(
        "write_key" => config.writeKey,
        value => value))
    JSON.parse(String(r.body))
end

"""
    delete_stream(config, stream_name)

Delete a stream

"""
function delete_stream(config::Config, stream_name::String)
    r = HTTP.request("DELETE", "$(config.baseUrl)/live/$(stream_name)";
    query=Dict("write_key" => config.writeKey))
    JSON.parse(String(r.body))
end


"""
    touch_stream(config, stream_name)

Modify the time to live for a stream, prevent a stream with no
recent updates from being deleted.

"""
function touch_stream(config::Config, stream_name::String)
    r = HTTP.request("PATCH", "$(config.baseUrl)/live/$(stream_name)";
    query=Dict("write_key" => config.writeKey))
    JSON.parse(String(r.body))
end

"""
    get_errors(config)

Return the errors for the client.

"""
function get_errors(config::Config)
    r = HTTP.request("GET", "$(config.baseUrl)/errors/$(config.writeKey)");
    JSON.parse(String(r.body))
end

"""
    get_warnings(config)

Return the warnings for the client.

"""
function get_warnings(config::Config)
    r = HTTP.request("GET", "$(config.baseUrl)/warnings/$(config.writeKey)");
    JSON.parse(String(r.body))
end

"""
    delete_errors(config)

Clear all errors for the client

"""
function delete_errors(config::Config)
    r = HTTP.request("DELETE", "$(config.baseUrl)/errors/$(config.writeKey)");
    JSON.parse(String(r.body))
end


"""
    delete_warnings(config)

Clear all of the warnings for the client

"""
function delete_warnings(config::Config)
    r = HTTP.request("DELETE", "$(config.baseUrl)/warnings/$(config.writeKey)");
    JSON.parse(String(r.body))
end

"""
    get_balance(config)

Return the balance associated with the write key that was specified
in the configuration.

"""
function get_balance(config::Config)::Float64
    r = HTTP.request("GET", "$(config.baseUrl)/balance/$(config.writeKey)");
    JSON.parse(String(r.body))
end

"""
    get_active(config)

Return the active submissions to stream that have predictions that
could be judged.

"""
function get_active(config::Config)::Array{String}
    r = HTTP.request("GET", "$(config.baseUrl)/active/$(config.writeKey)");
    JSON.parse(String(r.body))
end


"""
    submit(config)

Submit a prediction scenerio to a stream and delay horizon.

"""
function submit(config::Config, stream_name::String, values::Array{Float64}, delay::Number=config.delays[1])
    if length(values) != config.numPredictions
        throw(DimensionMismatch("Number of values must equal $(config.numPredictions)"))
    end

    values = join(values, ",")

    r = HTTP.request("PUT", "$(config.baseUrl)/submit/$(stream_name)";
    query=Dict(
        "write_key" => config.writeKey,
        "delay" => delay,
        "values" => values
    ))
    JSON.parse(String(r.body))
end

end # module
