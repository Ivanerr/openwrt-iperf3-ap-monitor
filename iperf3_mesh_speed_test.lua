#!/usr/bin/lua
local cjson = require "cjson"

-- ================= CONFIGURATION =================
local TELEGRAM_TOKEN = "YOUR_TELEGRAM_BOT_TOKEN"
local CHAT_ID = "YOUR_CHAT_ID"
local THRESHOLD_MBPS = 200
local AP_LIST = {
    { name = "Stairs AP", ip = "192.168.0.2"},
    { name = "Living Room AP", ip = "192.168.0.3" },
    { name = "Kitchen AP",     ip = "192.168.0.4" },
    { name = "Kabinet AP",      ip = "192.168.0.5" },
    { name = "Kidsroom AP",    ip="192.168.0.6"}
}
-- =================================================

-- Helper function to print verbose messages
local function verbose(msg)
    print(os.date("%Y-%m-%d %H:%M:%S") .. " [INFO] " .. msg)
end

-- Helper function to print errors
local function log_error(msg)
    print(os.date("%Y-%m-%d %H:%M:%S") .. " [ERROR] " .. msg)
end

-- Function to send Telegram Alert
local function send_telegram_alert(message)
    verbose("Sending Telegram alert: " .. message)
    -- Escape special characters for shell command
    local safe_message = message:gsub('"', '\\"')

    local cmd = string.format(
        'curl -s -X POST "https://api.telegram.org/bot%s/sendMessage" -d chat_id="%s" -d text="%s"',
        TELEGRAM_TOKEN, CHAT_ID, safe_message
    )

    local result = os.execute(cmd)
    if result ~= 0 and result ~= true then
        log_error("Failed to send Telegram message.")
    end
end

-- Function to run iperf3 and parse results
local function check_speed(ap)
    verbose("Starting speed test for: " .. ap.name .. " (" .. ap.ip .. ")")

    -- Command: -c client, -J json output, -t 5 seconds, -P 2 parallel streams (fills pipe better)
    -- --connect-timeout 3 prevents hanging if AP is down
    local cmd = string.format("iperf3 -c %s -J -t 1 -P 4 --connect-timeout 500 2>/dev/null", ap.ip)
    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local success, exit_type, exit_code = handle:close()

    if not output or output == "" then
        local err_msg = " zM-  o Connection Failed: " .. ap.name .. " (" .. ap.ip .. ") is unreachable or iperf3 server is not running."
        log_error(err_msg)
        send_telegram_alert(err_msg)
        return
    end

    -- Parse JSON
    local status, json_data = pcall(cjson.decode, output)

    if not status then
        local err_msg = " zM-  o JSON Error: Failed to parse iperf3 output for " .. ap.name .. "."
        log_error(err_msg)
        log_error("Raw output: " .. (output or "nil"))
        send_telegram_alert(err_msg)
        return
    end

    -- Check for iperf level errors (e.g., "error": "server busy")
    if json_data.error then
        local err_msg = " zM-  o iperf3 Error on " .. ap.name .. ": " .. json_data.error
        log_error(err_msg)
        send_telegram_alert(err_msg)
        return
    end

    -- Extract speed (bits per second)
    -- We look at 'end.sum_received' because we care about the speed receiving data at the target (or sum_sent if connection is good)
    -- Usually for TCP, sum_sent and sum_received are close, but received is the true delivery.
    local bits_per_second = 0
    if json_data["end"] and json_data["end"]["sum_received"] then
        bits_per_second = json_data["end"]["sum_received"]["bits_per_second"]
    elseif json_data["end"] and json_data["end"]["sum_sent"] then
        bits_per_second = json_data["end"]["sum_sent"]["bits_per_second"]
    else
        local err_msg = " zM-  o Data Error: Could not find throughput data in JSON for " .. ap.name
        log_error(err_msg)
        send_telegram_alert(err_msg)
        return
    end


    local mbps = bits_per_second / 1000000
    verbose(string.format("Result for %s: %.2f Mbps", ap.name, mbps))

    -- Check Threshold
    if mbps < THRESHOLD_MBPS then
        local warn_msg = string.format(" =^zM-( Low Speed Warning!\nAP: %s (%s)\nSpeed: %.2f Mbps\nThreshold: %d Mbps",
            ap.name, ap.ip, mbps, THRESHOLD_MBPS)
        send_telegram_alert(warn_msg)
    end
end

-- Main Execution Loop
verbose("--- Starting Scheduled Speed Test ---")
for _, ap in ipairs(AP_LIST) do
    check_speed(ap)
end
verbose("--- Speed Test Completed ---")
