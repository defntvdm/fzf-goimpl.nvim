local M = {}

local function execute_impl(type, interface)
	local result = { "}", "" }
	local command_success, command_output =
		pcall(vim.fn.system, { "impl", string.sub(type:lower(), 1, 1) .. " *" .. type, interface })

	if command_success then
		for line in command_output:gmatch("[^\r\n]+") do
			table.insert(result, line)
		end
	else
		vim.notify("Error while executing impl command: " .. command_output, 4)
	end

	table.insert(result, "")

	return result
end

M.impl = function()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()
	local node = require("nvim-treesitter.ts_utils").get_node_at_cursor(win)
	local node_type = node:type()
	if node_type ~= "type_identifier" then
		vim.notify("Set cursor to type", 4)
		return
	end
	local sr, sc, er, ec = node:range()
	local type = vim.api.nvim_buf_get_text(buf, sr, sc, er, ec, {})[1]

	require("fzf-lua").lsp_live_workspace_symbols({
		complete = function(selected)
			local suffix = "Interface]"
			if string.find(selected[1], "Interface]") == nil then
				vim.notify("Select interface", 4)
				return
			end
			local interface_name = string.sub(selected[1], string.find(selected[1], suffix) + #suffix + 1)
			interface_name = string.sub(interface_name, 1, string.find(interface_name, " "))
			local lines = execute_impl(type, interface_name)
			vim.print(lines)
			_, _, er, ec = node:parent():range()
			er = er
			vim.api.nvim_buf_set_text(buf, er, ec, er, ec, lines)
		end,
	})
end

return M
