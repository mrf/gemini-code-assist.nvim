---@mod gemini.api.gemini Gemini API implementation
---@brief [[
--- Implements the Gemini API for code generation.
--- Supports both API key and OAuth bearer token authentication.
---@brief ]]

local M = {}

local BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

--- Get authentication info
---@return string? auth_type "api_key" or "oauth"
---@return string? credential API key or access token
local function get_auth()
  local auth = require("gemini.auth")
  local auth_type = auth.get_auth_type()

  if auth_type == "api_key" then
    return "api_key", auth.get_api_key()
  elseif auth_type == "oauth" then
    return "oauth", auth.get_access_token()
  end

  return nil, nil
end

--- Build request headers
---@param auth_type string
---@param credential string
---@return table
local function get_headers(auth_type, credential)
  local headers = {
    ["Content-Type"] = "application/json",
  }

  if auth_type == "oauth" then
    headers["Authorization"] = "Bearer " .. credential
  end

  return headers
end

--- Build the API URL
---@param model string Model name
---@param endpoint string Endpoint name
---@param auth_type string
---@param credential string
---@return string
local function build_url(model, endpoint, auth_type, credential)
  local url = string.format("%s/models/%s:%s", BASE_URL, model, endpoint)

  -- API key goes in URL, OAuth uses header
  if auth_type == "api_key" then
    url = url .. "?key=" .. credential
  end

  return url
end

--- Build request body
---@param prompt string|table
---@param opts table
---@return table
local function build_body(prompt, opts)
  local contents

  if type(prompt) == "string" then
    contents = {
      {
        role = "user",
        parts = { { text = prompt } },
      },
    }
  else
    contents = prompt
  end

  return {
    contents = contents,
    generationConfig = {
      temperature = opts.temperature or 0.7,
      topP = opts.top_p or 0.95,
      maxOutputTokens = opts.max_tokens or 1024,
      stopSequences = opts.stop_sequences,
    },
  }
end

--- Generate content (non-streaming)
---@param prompt string|table
---@param model string
---@param opts table
---@param callback function
function M.generate_content(prompt, model, opts, callback)
  local client = require("gemini.api.client")

  local auth_type, credential = get_auth()
  if not auth_type or not credential then
    callback({ message = "Not authenticated. Set GEMINI_API_KEY or run 'gemini login'" }, nil)
    return
  end

  local url = build_url(model, "generateContent", auth_type, credential)
  local headers = get_headers(auth_type, credential)
  local body = build_body(prompt, opts)

  client.request(url, {
    method = "POST",
    headers = headers,
    body = body,
  }, function(req_err, response)
    if req_err then
      callback(req_err, nil)
      return
    end

    -- Parse response
    if response.candidates and response.candidates[1] then
      local candidate = response.candidates[1]
      if candidate.content and candidate.content.parts then
        local text = ""
        for _, part in ipairs(candidate.content.parts) do
          if part.text then
            text = text .. part.text
          end
        end
        callback(nil, {
          text = text,
          finish_reason = candidate.finishReason,
        })
        return
      end
    end

    -- Handle error response
    if response.error then
      callback({ message = response.error.message }, nil)
    else
      callback({ message = "Invalid response format" }, nil)
    end
  end)
end

--- Stream content
---@param prompt string|table
---@param model string
---@param opts table
---@param on_chunk function
---@param on_done function
function M.stream_content(prompt, model, opts, on_chunk, on_done)
  local client = require("gemini.api.client")
  local streaming = require("gemini.api.streaming")

  local auth_type, credential = get_auth()
  if not auth_type or not credential then
    on_chunk(nil, "Not authenticated. Set GEMINI_API_KEY or run 'gemini login'")
    on_done(false)
    return
  end

  local url = build_url(model, "streamGenerateContent", auth_type, credential)
  local headers = get_headers(auth_type, credential)
  local body = build_body(prompt, opts)

  -- Add SSE parameter
  if auth_type == "api_key" then
    url = url .. "&alt=sse"
  else
    url = url .. "?alt=sse"
  end

  client.stream(url, {
    method = "POST",
    headers = headers,
    body = body,
  }, function(line, stream_err)
    if stream_err then
      on_chunk(nil, stream_err)
      return
    end

    local chunk = streaming.parse_sse_line(line)
    if chunk then
      on_chunk(chunk, nil)
    end
  end, on_done)
end

return M
