module Microprediction

using HTTP
using JSON
using TimeSeries

struct Transaction 
    """A unique identifier of the transaction"""
    transaction_id::AbstractString
    "The time the settlement happened"
    settlement_time::DateTime
    "The amount changed"
    amount::Float64
    "The budget of the stream"
    budget::Float64
    "The name of the stream"
    stream::AbstractString
    "The prediction horizon or delay"
    delay::Int64
    "The actual value of the stream"
    value::Float64
    "Total submissions received"
    submissions_count::Int64
    "Total submissions that were close"
    submissions_close::Int64
    "Stream owner code"
    stream_owner_code::AbstractString
    "Recipient code"
    recipient_code::AbstractString

    "Construct a new Transaction"
    function Transaction(transaction_id::AbstractString, data::Dict{AbstractString,Any})
        new(transaction_id,
        DateTime(replace(data["settlement_time"], r"\.\d*$" => ""), Dates.DateFormat("yyyy-mm-dd HH:MM:SS.s")),
        parse(Float64, data["amount"]),
        parse(Float64, data["budget"]),
        data["stream"],
        parse(Int64, data["delay"]),
        parse(Float64, data["value"]),
        parse(Int64, data["submissions_count"]),
        parse(Int64, data["submissions_close"]),
        data["stream_owner_code"],
        data["recipient_code"])
    end
end

struct TransferTransaction 
    "The time the settlement happened"
    settlement_time::DateTime
    "The type of transaction"
    type::AbstractString
    "The public source key of the transaction"
    source::AbstractString
    "The public recipient key of the transactions"
    recipient::AbstractString
    "The maximum amount that this transaction could give"
    max_to_give::Float64
    "The maximum amount the source key could receive"
    max_to_receive::Float64
    "The amount given"
    given::Float64
    "The amount received"
    received::Float64
    "A flag that indicates if the transaction was successful."
    success::Bool
    "A reason for why the transaction could not be successful"
    reason::AbstractString


end
    

struct Config
    "The base URL of the microprediction.org API"
    baseUrl::AbstractString
    "The failover URL of the microprediction.org API"
    failoverBaseUrl::AbstractString
    "The number of predictions that should be returned from the predictive distribution."
    numPredictions::Int64
    "An array of delays for forecasts"
    delays::Array{Int64}
    "The minimum balance of a key before it is considered bankrupt"
    minBalance::Float64
    "The minimum length of a key if it is going to write data"
    minLen::Int64
    "The write key to use"
    writeKey::Union{Nothing,AbstractString}

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
function get_current_value(config::Config, stream_name::AbstractString)::Union{Float64,Nothing}
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
function get_leaderboard(config::Config, stream_name::AbstractString, delay::Number)::Union{Nothing,Dict{AbstractString,Float64}}
    r = HTTP.request("GET", "$(config.baseUrl)/leaderboards/$(stream_name)"; query=Dict("delay" => delay))
    return JSON.parse(String(r.body))
end


"""
    get_overall(config)

Return the overall leaderboard.

"""
function get_overall(config::Config)::Dict{AbstractString,Float64}
    r = HTTP.request("GET", "$(config.baseUrl)/overall")
    return JSON.parse(String(r.body))
end


"""
    get_sponsors(config)

Return the sponsors of streams.

"""
function get_sponsors(config::Config)::Dict{AbstractString,String}
    r = HTTP.request("GET", "$(config.baseUrl)/sponsors/")
    return JSON.parse(String(r.body))
end

"""
    get_budgets(config)

Return the budgets of existing streams.

"""
function get_budgets(config::Config)::Dict{AbstractString,Float64}
    r = HTTP.request("GET", "$(config.baseUrl)/budgets/")
    return JSON.parse(String(r.body))
end


"""
    get_summary(config, stream_name)

Return the summary information about a stream

"""
function get_summary(config::Config, stream_name::AbstractString)
    r = HTTP.request("GET", "$(config.baseUrl)/live/summary::$(stream_name)")
    data = JSON.parse(String(r.body))

    return data
end

"""
    get_lagged(config, stream_name)

Return lagged time and values of a time series. The newest times are placed at 
the start of the result array.  The values are a Float64 of Unix epoch times.

"""
function get_lagged(config::Config, stream_name::AbstractString)::TimeArray{Float64,1,DateTime,Array{Float64,1}}
    r = HTTP.request("GET", "$(config.baseUrl)/live/lagged::$(stream_name)")
    data = JSON.parse(String(r.body))
    live_data = permutedims(reshape(collect(Iterators.Flatten(data)), (2, :)))
    live_data = live_data[sortperm(live_data[:, 1]), :]
    live_dates = Dates.unix2datetime.(live_data[:, 1])
    live_values = live_data[:, 2]
    TimeArray(live_dates, live_values)
end



"""
    get_delayed_value(config, stream_name[, delay])

Return a quarentined value from a stream.

"""
function get_delayed_value(config::Config, stream_name::AbstractString, delay::Number=config.delays[1])::Float64
    r = HTTP.request("GET", "$(config.baseUrl)/live/delayed::$(delay)::$(stream_name)")
    JSON.parse(String(r.body))
end

"""
    write_to_stream(config, stream_name, value)

Add a value to a stream, if the stream does not exist it is created.

"""
function write_to_stream(config::Config, stream_name::AbstractString, value::Number)
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
function delete_stream(config::Config, stream_name::AbstractString)
    r = HTTP.request("DELETE", "$(config.baseUrl)/live/$(stream_name)";
    query=Dict("write_key" => config.writeKey))
    JSON.parse(String(r.body))
end


"""
    touch_stream(config, stream_name)

Modify the time to live for a stream, prevent a stream with no
recent updates from being deleted.

"""
function touch_stream(config::Config, stream_name::AbstractString)
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
function get_active(config::Config)::Array{AbstractString}
    r = HTTP.request("GET", "$(config.baseUrl)/active/$(config.writeKey)");
    JSON.parse(String(r.body))
end


"""
    submit(config)

Submit a prediction scenerio to a stream and delay horizon.

"""
function submit(config::Config, stream_name::AbstractString, values::Array{Float64}, delay::Number=config.delays[1])
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

"""
    cancel()

Cancel a previously submitted prediction

"""
function cancel(config::Config, stream_name::AbstractString, delay::Number)
    r = HTTP.request("DELETE", "$(config.baseUrl)/submit/$(stream_name)";
    query=Dict(
        "write_key" => config.writeKey,
        "delay" => delay
    ))
    JSON.parse(String(r.body))    
end


"""
    get_transactions()

Return transactions associated with the specified write_key

"""
function get_transactions(config::Config)::Array{Transaction}
    r = HTTP.request("GET", "$(config.baseUrl)/transactions/$(config.writeKey)/");
    data = JSON.parse(String(r.body))
    parsed = map(x -> Transaction(x...), data)
    return parsed
end

struct PerformanceRecord
    stream_name::AbstractString
    delay::Int64
    performance::Float64

    "Construct a new PerformanceRecord"
    function PerformanceRecord(stream_name::AbstractString, delay::Int64, performance)
        new(stream_name,
        delay,
        performance)
    end
end

"""
    get_performance()

Return the current performance for the specified write_key

"""
function get_performance(config::Config)::Array{PerformanceRecord} 
    r = HTTP.request("GET", "$(config.baseUrl)/performance/$(config.writeKey)");
    data = JSON.parse(String(r.body))
    result = [];
    for (key, value) in data
        raw_delay, stream_name = split(key, "::")
        delay = parse(Int64, raw_delay)
        push!(result, PerformanceRecord(stream_name, delay, value))
    end
    return result
end

end # module
