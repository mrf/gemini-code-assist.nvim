---@mod gemini.api.streaming Streaming response handler
---@brief [[
--- Handles Server-Sent Events (SSE) parsing for streaming responses.
---@brief ]]

local M = {}

--- Parse a single SSE line
---@param line string
---@return table?
function M.parse_sse_line(line)
	if not line or line == "" then
		return nil
	end

	-- SSE format: data: {...}
	local data = line:match("^data:%s*(.+)$")
	if not data then
		return nil
	end

	-- Parse JSON
	local ok, parsed = pcall(vim.json.decode, data)
	if not ok then
		return nil
	end

	-- Extract text from response
	if parsed.candidates and parsed.candidates[1] then
		local candidate = parsed.candidates[1]
		if candidate.content and candidate.content.parts then
			local text = ""
			for _, part in ipairs(candidate.content.parts) do
				if part.text then
					text = text .. part.text
				end
			end
			return {
				text = text,
				finish_reason = candidate.finishReason,
			}
		end
	end

	return nil
end

--- Create a streaming accumulator
---@return table
function M.create_accumulator()
	return {
		text = "",
		chunks = {},

		--- Add a chunk
		---@param self table
		---@param chunk table
		add = function(self, chunk)
			if chunk and chunk.text then
				self.text = self.text .. chunk.text
				table.insert(self.chunks, chunk)
			end
		end,

		--- Get accumulated text
		---@param self table
		---@return string
		get_text = function(self)
			return self.text
		end,

		--- Clear accumulator
		---@param self table
		clear = function(self)
			self.text = ""
			self.chunks = {}
		end,
	}
end

return M
