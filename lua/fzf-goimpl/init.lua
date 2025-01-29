local M = {}

local builtin = require("fzf-lua.previewer.builtin")

local InterfacePreviewer = builtin.buffer_or_file:extend()

function InterfacePreviewer:new(o, opts, fzf_win)
	InterfacePreviewer.super.new(self, o, opts, fzf_win)
	setmetatable(self, InterfacePreviewer)
	return self
end

local function parse_entry(s)
	local symbol = string.gmatch(s, "%S+")()
	local path, line, col = s:match("\t\t\t([^:]+):(%d+):(%d+)")
	return {
		symbol = symbol,
		path = path,
		line = line,
		col = col,
	}
end

function InterfacePreviewer:parse_entry(entry_str)
	return parse_entry(entry_str)
end

local function execute_impl(type, interface)
	local result = { "" }
	local command_success, command_output =
		pcall(vim.fn.system, { "impl", string.sub(type:lower(), 1, 1) .. " *" .. type, interface })

	if command_success then
		for line in command_output:gmatch("[^\r\n]+") do
			table.insert(result, line)
		end
	else
		vim.notify("Error while executing impl command: " .. command_output, 4)
	end

	return result
end

local function make_entry(s)
	local item = vim.lsp.util.symbols_to_items({ s })[1]
	local symbol = item.text:sub(#item.kind + 4)
	local result = {
		symbol .. string.rep(" ", 30 - #symbol),
		"\t\t\t",
		item.filename,
		":",
		item.lnum,
		":",
		item.col,
	}
	return table.concat(result, "")
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
	local fzf = require("fzf-lua")
	fzf.fzf_live(function(query)
		return function(cb)
			local co = coroutine.running()
			local all_symbols, err = vim.lsp.buf_request_sync(buf, "workspace/symbol", { query = query }, 10000)
			if err ~= nil then
				vim.notify("Error while getting interfaces: " .. err, 4)
			end
			for _, symbols in ipairs(all_symbols) do
				if symbols.result == nil then
					goto continue
				end
				for _, s in ipairs(symbols.result) do
					if s.kind == vim.lsp.protocol.SymbolKind.Interface then
						cb(make_entry(s))
					end
				end
				::continue::
			end
			cb()
		end
	end, {
		previewer = InterfacePreviewer,
		complete = function(selected)
			local lines = execute_impl(type, parse_entry(selected[1]).symbol)
			_, _, er, _ = node:parent():range()
			er = er + 1
			vim.api.nvim_buf_set_lines(buf, er, er, true, lines)
		end,
	})
end

return M
