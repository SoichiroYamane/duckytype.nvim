local settings = require("duckytype.settings")
local constants = require("duckytype.constants")

local buffer
local window
local started
local finished
local expected = nil

local namespace = vim.api.nvim_create_namespace("DuckyType.nvim")

local Methods = {}

Methods.megamind = table.concat({
	"⠀⣞⢽⢪⢣⢣⢣⢫⡺⡵⣝⡮⣗⢷⢽⢽⢽⣮⡷⡽⣜⣜⢮⢺⣜⢷⢽⢝⡽⣝",
	"⠸⡸⠜⠕⠕⠁⢁⢇⢏⢽⢺⣪⡳⡝⣎⣏⢯⢞⡿⣟⣷⣳⢯⡷⣽⢽⢯⣳⣫⠇",
	"⠀⠀⢀⢀⢄⢬⢪⡪⡎⣆⡈⠚⠜⠕⠇⠗⠝⢕⢯⢫⣞⣯⣿⣻⡽⣏⢗⣗⠏⠀",
	"⠀⠪⡪⡪⣪⢪⢺⢸⢢⢓⢆⢤⢀⠀⠀⠀⠀⠈⢊⢞⡾⣿⡯⣏⢮⠷⠁⠀⠀⠀",
	"⠀⠀⠀⠈⠊⠆⡃⠕⢕⢇⢇⢇⢇⢇⢏⢎⢎⢆⢄⠀⢑⣽⣿⢝⠲⠉⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⡿⠂⠠⠀⡇⢇⠕⢈⣀⠀⠁⠡⠣⡣⡫⣂⣿⠯⢪⠰⠂⠀⠀⠀⠀",
	"⠀⠀⠀⠀⡦⡙⡂⢀⢤⢣⠣⡈⣾⡃⠠⠄⠀⡄⢱⣌⣶⢏⢊⠂⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⢝⡲⣜⡮⡏⢎⢌⢂⠙⠢⠐⢀⢘⢵⣽⣿⡿⠁⠁⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠨⣺⡺⡕⡕⡱⡑⡆⡕⡅⡕⡜⡼⢽⡻⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⣼⣳⣫⣾⣵⣗⡵⡱⡡⢣⢑⢕⢜⢕⡝⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⣴⣿⣾⣿⣿⣿⡿⡽⡑⢌⠪⡢⡣⣣⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⡟⡾⣿⢿⢿⢵⣽⣾⣼⣘⢸⢸⣞⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠁⠇⠡⠩⡫⢿⣝⡻⡮⣒⢽⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
}, "\n")

Methods.Expect = function(key, T)
	local v = T[key]
	if v == nil then
		error(string.format("\nno «%s»?\n%s", tostring(key), Methods.megamind))
	end
	return v
end

Methods.Print = function(structure, prefix)
	prefix = prefix or "X"
	local s_type = type(structure)
	if s_type ~= "table" then
		print(string.format("%s = %s (%s)", prefix, tostring(structure), s_type))
		return
	end
	print(string.format("%s (%s)", prefix, s_type))
	for k, v in pairs(structure) do
		Methods.Print(v, string.format("%s [%s]", prefix, tostring(k)))
	end
end

Methods.Update = function(T, U)
	if type(T) ~= "table" or type(U) ~= "table" then
		Methods.Print(T, "defaults")
		Methods.Print(U, "update")
		error("Invalid types given in Update(T, U) (see above)!")
	end
	for k, v in pairs(U) do
		local c = T[k]
		if c == nil then
			Methods.Print(U)
			error(string.format("Update was unsuccessful, because key «%s» is invalid!", tostring(k)))
		end
		if type(c) == "table" then
			Methods.Update(c, v)
		else
			T[k] = v
		end
	end
end

Methods.NewGame = function(key_override)
	if buffer == nil then
		error(string.format("\nno buffer?\n%s", Methods.megamind))
	end
	if window == nil then
		error(string.format("\nno window?\n%s", Methods.megamind))
	end

	local key = key_override or settings.expected
	local lookup_table = Methods.Expect(key, constants)

	expected = {}
	-- fill expected with random words from lookup_table
	local line = {}
	local line_width = 0
	math.randomseed(os.time())
	for _ = 1, settings.number_of_words do
		local random = lookup_table[math.ceil(math.random() * #lookup_table)]
		line_width = line_width + #random + 1
		if line_width >= settings.window_config.width then
			-- line overflow, start a new line
			local line_text = string.format("%s ", table.concat(line, " "))
			table.insert(expected, line_text)
			line = {}
			line_width = #random
		end
		table.insert(line, random)
	end

	-- insert whatever was still remaining (it did not meet the line_width wrap)
	local line_text = string.format("%s ", table.concat(line, " "))
	table.insert(expected, line_text)

	-- remove the last trailing space from expected lines
	local lastline = expected[#expected]
	expected[#expected] = lastline:sub(1, #lastline - 1)

	-- pad the current buffer with some empty strings, so the virtual text
	-- highlighting shows. and +3 more just for good measure.
	local empty = { "", "", "" }
	for _, _ in ipairs(expected) do
		table.insert(empty, "")
	end
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, empty)

	-- TODO proper timing, starts on first keystroke instead of when window shows
	started = os.time()
	finished = nil
end

Methods.ShowResultOptions = function()
	vim.schedule(function()
		-- Display "continue" centered in the window
		local width = vim.api.nvim_win_get_width(window)
		local continue_text = "[continue]"
		local padding_continue = math.floor((width - #continue_text) / 2)
		local padded_continue = string.rep(" ", padding_continue) .. continue_text

		-- Determine the line where the continue button will be displayed
		local button_line = #expected + 4

		-- Ensure the line for the button exists
		local total_lines = vim.api.nvim_buf_line_count(buffer)
		local lines_needed = button_line + 1 - total_lines
		if lines_needed > 0 then
			-- Insert blank lines up to the button line
			for _ = 1, lines_needed do
				vim.api.nvim_buf_set_lines(buffer, -1, -1, false, { "" })
			end
		end

		-- Ensure the line has enough spaces
		local line_content = vim.api.nvim_buf_get_lines(buffer, button_line, button_line + 1, false)[1] or ""
		if #line_content < padding_continue + #continue_text then
			local required_length = padding_continue + #continue_text
			line_content = line_content .. string.rep(" ", required_length - #line_content)
			vim.api.nvim_buf_set_lines(buffer, button_line, button_line + 1, false, { line_content })
		end

		-- Adjust 'col' to be within line length
		local col = math.min(padding_continue, #line_content - #continue_text)

		-- Create a namespace for the virtual text
		namespace = namespace or vim.api.nvim_create_namespace("DuckyTypeNamespace")

		-- Define highlight group for the continue button
		vim.api.nvim_set_hl(0, "DuckyTypeButton", { bg = "#2D3F76", fg = "White", bold = true })

		-- Set virtual text for the continue button
		vim.api.nvim_buf_set_extmark(buffer, namespace, button_line, col, {
			virt_text = { { "[CONTINUE]", "DuckyTypeButton" } },
			virt_text_pos = "overlay",
		})

		-- Function to handle button press
		_G.ConfirmButtonSelection = function()
			-- Close the current window and buffer
			if vim.api.nvim_win_is_valid(window) then
				vim.api.nvim_win_close(window, true)
			end
			if vim.api.nvim_buf_is_valid(buffer) then
				vim.api.nvim_buf_delete(buffer, { force = true })
			end

			-- Reset variables
			buffer = nil
			window = nil
			started = nil
			finished = nil
			expected = nil

			-- Start a new game
			Methods.Start()
		end

		-- Map Enter key to confirm selection
		vim.api.nvim_buf_set_keymap(
			buffer,
			"n",
			"<CR>",
			":lua ConfirmButtonSelection()<CR>",
			{ noremap = true, silent = true }
		)

		-- Move cursor to the continue button line (1-based indexing)
		vim.api.nvim_win_set_cursor(window, { button_line + 1, col + 1 })
		vim.cmd("stopinsert") -- Switch to normal mode
	end)
end

Methods.Start = function(key_override)
	local key = key_override or settings.expected
	local _ = Methods.Expect(key, constants)

	buffer = vim.api.nvim_create_buf(false, true)
	if settings.centered then
		local c = (vim.api.nvim_get_option("columns") - settings.window_config.width) / 2
		local r = (vim.api.nvim_get_option("lines") - settings.window_config.height) / 2
		settings.window_config.col = c
		settings.window_config.row = r
	end
	window = vim.api.nvim_open_win(buffer, true, settings.window_config)

	Methods.NewGame(key_override)

	vim.api.nvim_buf_attach(buffer, false, {
		on_lines = function(...)
			local done = Methods.RedrawBuffer()
			if done then
				if finished == nil then
					finished = os.time()
				end
				local elapsed = finished - started
				local total = 0
				for _, line in ipairs(expected) do
					total = total + #line
				end
				local wpm_estimate = (total / settings.average_word_length) / (elapsed / 60.0)
				local m1 = string.format("%d characters in %d seconds", total, elapsed)
				local m2 = string.format("roughly %d wpm!", wpm_estimate)

				Methods.HighlightLine(#expected, ":: ", m1)
				Methods.HighlightLine(#expected + 1, ":: ", m2)

				Methods.ShowResultOptions()

				return true
			end
		end,
	})

	Methods.RedrawBuffer()
	vim.cmd("startinsert")
end

Methods.Setup = function(update)
	update = update or {}
	Methods.Update(settings, update)

	-- NOTE: thank `@bryant-the-coder` for this idea
	-- introduce user command with autocompletion
	vim.api.nvim_create_user_command("DuckyType", function(input)
		local option = input.args
		if #option == 0 then
			option = nil
		end
		Methods.Start(option)
	end, {
		force = true,
		nargs = "*",
		complete = function(prefix)
			local names = {}
			for name, _ in pairs(constants) do
				if Methods.StartsWith(name, prefix) then
					table.insert(names, name)
				end
			end
			return names
		end,
	})
end

Methods.StartsWith = function(s, prefix)
	return s:find(prefix, 1, true) == 1
end

Methods.LongestPrefixLength = function(s, prefix)
	local e = {}
	for i = 1, #s do
		table.insert(e, s:sub(i, i))
	end
	for i = 1, #prefix do
		if e[i] ~= prefix:sub(i, i) then
			return i - 1
		end
	end
	return #prefix
end

Methods.HighlightLine = function(line_index, line, prefix)
	local length = Methods.LongestPrefixLength(line, prefix)
	local good = line:sub(1, length)
	local bad = line:sub(length + 1)
	local remaining = prefix:sub(length + 1)
	local opts = {
		id = line_index + 1,
		virt_text = {
			{ good, settings.highlight.good },
			{ bad, settings.highlight.bad },
			{ remaining, settings.highlight.remaining },
		},
		virt_text_pos = "overlay",
	}
	local _ = vim.api.nvim_buf_set_extmark(buffer, namespace, line_index, 0, opts)
	return #remaining == 0
end

Methods.RedrawBuffer = function()
	local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
	local done = true
	for index = 1, #expected do
		local line = lines[index]
		if line == nil then
			return false
		end
		local prefix = expected[index]
		if prefix == nil then
			return done
		end
		local okay = Methods.HighlightLine(index - 1, line, prefix)
		done = done and okay
		local cursor = vim.api.nvim_win_get_cursor(window)
		local row = cursor[1]
		if okay and row == index then
			-- jump to next line if current line is okay
			vim.api.nvim_input("<Esc>jI")
			-- TODO (?)
			-- vim.api.nvim_win_set_cursor(window, { row + 1, 0 })
		end
	end
	return done
end

return Methods
