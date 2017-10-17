-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--[[
Monitors Parquet output plugin for errors, alerting when they pass a given threshold.

```lua
filename = 'parquet_output_error_monitor.lua'
message_matcher = 'Fields[Type] == "hindsight.plugins"'
ticker_interval = 60
preserve_data = false

alert = {
  disabled = false,
  prefix = true,
  throttle = 1440, -- default to once a day (inactivity and ingestion_error default to 90)
  modules = {
    email = {recipients = {"trink@mozilla.com"}},
  },

  thresholds = {
    "output.s3_parquet" = {
      percent = 1 -- alert if more than 1% of outputs cause an error
      number = 100 -- alert if there are more than 100 errors reported at once
    }
  }
}
```
--]]
local alert      = require "heka.alert"
local thresholds = read_config("alert").thresholds

for k, t in pairs(thresholds) do
    if t.number then
        assert(type(t.number) == "number" and t.number > 0,
               string.format("alert: \"%s\".number must contain a number of message failures", k))
    end
    if t.percent then
        assert(type(t.percent) == "number" and t.percent > 0 and t.percent <= 100,
               string.format("alert: \"%s\".percent must contain a percentage of message failures (1-100)", k))
    end
end

local columns = {
    ["Inject Message Count"] = 1,
    ["Inject Message Bytes"] = 2,
    ["Process Message Count"] = 3,
    ["Process Message Failures"] = 4,
    ["Current Memory"] = 5,
    ["Max Memory"] = 6,
    ["Max Output"] = 7,
    ["Max Instructions"] = 8,
    ["Message Matcher Avg (ns)"] = 8,
    ["Message Matcher SD (ns)"] = 9,
    ["Process Message Avg (ns)"] = 10,
    ["Process Message SD (ns)"] = 11,
    ["Timer Event Avg (ns)"] = 12,
    ["Timer Event SD (ns)"] = 13
}


function process_message()
    local delta = read_message("Fields")
    for k, t in pairs(thresholds) do
        local count = delta[k][columns["Inject Message Count"]]
        local fails = delta[k][columns["Inject Message Failures"]]
        local fail_percent = count / fails * 100
        if fails > t["number"] then
            alert.send(k, "number", string.format("%d recent messages failed", fails))
        end
        if fail_percent > t["percent"] then
            alert.send(k, "percent", string.format("%g%% of recent messages failed", fail_percent))
        end
    end
end
