using Test
using Microprediction

c = Microprediction.Config()

@test typeof(c) == Microprediction.Config

test_stream_name = "emojitracker-twitter-grinning_face_with_smiling_eyes.json"

@test Microprediction.get_current_value(c, test_stream_name) != nothing
@test Microprediction.get_current_value(c, "nonexisting-string.json") == nothing

@test Microprediction.get_leaderboard(c, test_stream_name, 70) != nothing

@test Microprediction.get_overall(c) != nothing
@test Microprediction.get_sponsors(c) != nothing
@test Microprediction.get_budgets(c) != nothing

@test Microprediction.get_summary(c, test_stream_name) != nothing

@test Microprediction.get_lagged(c, test_stream_name) != nothing

@test Microprediction.get_delayed_value(c, test_stream_name) != nothing

write_config = Microprediction.Config("82457d14c37df7043cb5d6c0b53bdb30")

@test write_config.writeKey != Nothing

# Test writing to a stream

Microprediction.submit(write_config, "emojitracker-twitter-winking_face.json",
    fill(42.0, (1, 225)))

