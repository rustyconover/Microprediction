println("testing")

using Test
using Microprediction

c = Microprediction.Config()

println(typeof(c))

@test c !== Nothing

println(typeof(c))

test_stream_name = "emojitracker-twitter-grinning_face_with_smiling_eyes.json"

println(Microprediction.get_current_value(c, test_stream_name))
println(Microprediction.get_current_value(c, "nonexisting-string.json"))

println(Microprediction.get_leaderboard(c, test_stream_name, 70))
println(Microprediction.get_overall(c))
println(Microprediction.get_sponsors(c))
println(Microprediction.get_budgets(c))

println(Microprediction.get_summary(c, test_stream_name))

println(Microprediction.get_lagged_values(c, test_stream_name))
println(Microprediction.get_lagged_times(c, test_stream_name))

println(Microprediction.get_delayed_value(c, test_stream_name))
