module Microprediction

using HTTP
using JSON

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

    function Config()
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

        new(baseUrl, failoverBaseUrl, numPredictions, delays, minBalance, minLen)
    end
end

struct MicroReader
    config::Config

end

"""
    get_current_value(config, stream_name)

Return the latest value from the specified stream. If the stream is
unknown return nothing.

"""
function get_current_value(config::Config, stream_name::String)::Union{Number,Nothing}
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
function get_leaderboard(config::Config, stream_name::String, delay::Number)::Union{Nothing,Dict{String,Number}}
    r = HTTP.request("GET", "$(config.baseUrl)/leaderboards/$(stream_name)"; query=Dict("delay" => delay))
    return JSON.parse(String(r.body))
end


"""
    get_overall(config)

Return the overall leaderboard.

"""
function get_overall(config::Config)::Dict{String,Number}
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
function get_budgets(config::Config)::Dict{String,Number}
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
    get_lagged_values(config, stream_name)

Return lagged values of stream.

"""
function get_lagged_values(config::Config, stream_name::String)::Array{Number}
    r = HTTP.request("GET", "$(config.baseUrl)/live/lagged_values::$(stream_name)")
    JSON.parse(String(r.body))
end

"""
    get_lagged_times(config, stream_name)

Return lagged times of a time series.

"""
function get_lagged_times(config::Config, stream_name::String)::Array{Number}
    r = HTTP.request("GET", "$(config.baseUrl)/live/lagged_times::$(stream_name)")
    JSON.parse(String(r.body))
end

"""
    get_delayed_value(config, stream_name[, delay])

Return a quarentined value from a stream.

"""
function get_delayed_value(config::Config, stream_name::String, delay::Number=config.delays[1])::Number
    r = HTTP.request("GET", "$(config.baseUrl)/live/delayed::$(delay)::$(stream_name)")
    JSON.parse(String(r.body))
end


end # module
