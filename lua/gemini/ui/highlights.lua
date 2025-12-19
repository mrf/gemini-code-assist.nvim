---@mod gemini.ui.highlights Highlight group management
---@brief [[
--- Defines and manages highlight groups for the plugin.
---@brief ]]

local M = {}

--- Setup highlight groups
---@param config GeminiConfig
function M.setup(config)
	local hl = config.ui and config.ui.suggestion_hl or "Comment"

	-- Ghost text highlight
	vim.api.nvim_set_hl(0, "GeminiSuggestion", { link = hl, default = true })

	-- Chat highlights
	vim.api.nvim_set_hl(0, "GeminiChatUser", { link = "Title", default = true })
	vim.api.nvim_set_hl(0, "GeminiChatAssistant", { link = "Normal", default = true })
	vim.api.nvim_set_hl(0, "GeminiChatCode", { link = "String", default = true })

	-- Status highlights
	vim.api.nvim_set_hl(0, "GeminiStatusOk", { link = "DiagnosticOk", default = true })
	vim.api.nvim_set_hl(0, "GeminiStatusWarn", { link = "DiagnosticWarn", default = true })
	vim.api.nvim_set_hl(0, "GeminiStatusError", { link = "DiagnosticError", default = true })
	vim.api.nvim_set_hl(0, "GeminiStatusLoading", { link = "DiagnosticInfo", default = true })
end

return M
