--!nonstrict

local history = {}
local sessionExprs = {}
local currentInput = ""
local inputGeneration = 0
local historyIndex = nil
local draftInput = ""
local previousOutputLineCount = 0
local scrollRevision = 0
local isEvaluating = false
local heldChord = nil
local heldElapsedMs = 0

local REPEAT_DELAY_MS = 400
local REPEAT_INTERVAL_MS = 120

local function trimmed(value)
  return noctalia.string.trim(value or "")
end

local function outputLines(value)
  local lines = {}
  local normalized = (value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  for line in (normalized .. "\n"):gmatch("(.-)\n") do
    if trimmed(line) ~= "" then
      table.insert(lines, line)
    end
  end
  return lines
end

local function appendHistory(expr, result, isError, copyable)
  table.insert(history, {
    expr = expr,
    result = result,
    isError = isError,
    copyable = copyable,
  })
  scrollRevision += 1
end

local function historyRows()
  if #history == 0 then
    return {
      ui.label({
        text = "Enter a Numbat expression, for example: 2 m + 30 cm",
        color = "on_surface_variant",
        textAlign = "center",
      }),
    }
  end

  local rows = {}
  for index, item in ipairs(history) do
    local onResultClick = nil
    if item.copyable then
      onResultClick = function()
        onCopyResult(index)
      end
    end

    table.insert(rows, ui.column({
      key = "history-" .. index,
      gap = 4,
      padding = 10,
      fill = item.isError and "error/0.10" or "surface_container",
      radius = 10,
    }, {
      ui.label({
        text = "> " .. item.expr,
        color = "on_surface_variant",
        maxLines = 3,
      }),
      ui.button({
        text = item.result,
        variant = "ghost",
        contentAlign = "start",
        enabled = item.copyable,
        tooltip = item.copyable and "Copy result" or "",
        onClick = onResultClick,
      }),
    }))
  end
  return rows
end

local function render()
  panel.render(ui.column({ gap = 12, padding = 14, height = 560 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "calculator", size = 18, color = "primary" }),
      ui.label({
        text = "Numbat",
        fontSize = 16,
        fontWeight = "bold",
        color = "on_surface",
        flexGrow = 1,
      }),
      ui.button({
        glyph = "trash",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Clear session",
        enabled = not isEvaluating and #history > 0,
        onClick = "onClear",
      }),
      ui.button({
        glyph = "x",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Close",
        onClick = "onClose",
      }),
    }),
    ui.scroll({
      flexGrow = 1,
      gap = 8,
      stickToBottom = true,
      scrollToBottomRev = scrollRevision,
    }, historyRows()),
    ui.input({
      key = "expr-" .. inputGeneration,
      value = currentInput,
      placeholder = isEvaluating and "Evaluating…" or "Enter a Numbat expression…",
      controlSize = "lg",
      focus = true,
      enabled = not isEvaluating,
      onChange = "onInputChange",
      onSubmit = "onEvaluate",
    }),
    ui.label({
      text = "Enter: evaluate • Up/Down: history • Click result: copy",
      fontSize = 11,
      color = "on_surface_variant",
      textAlign = "center",
    }),
  }))
end

local function commandFor(expr)
  local command = {
    "numbat",
    "--pretty-print=never",
    "--color=never",
    "--intro-banner=off",
  }
  for _, prior in ipairs(sessionExprs) do
    table.insert(command, "-e")
    table.insert(command, prior)
  end
  table.insert(command, "-e")
  table.insert(command, expr)
  return command
end

local function evaluate(expr)
  isEvaluating = true
  render()

  noctalia.runAsync(commandFor(expr), function(result)
    if result.exitCode == 0 then
      local lines = outputLines(result.stdout)
      local newLines = {}
      for index = previousOutputLineCount + 1, #lines do
        table.insert(newLines, lines[index])
      end

      local output = trimmed(table.concat(newLines, "\n"))
      local hasOutput = output ~= ""
      appendHistory(expr, hasOutput and output or "Defined", false, hasOutput)
      table.insert(sessionExprs, expr)
      previousOutputLineCount = #lines
    else
      local output = trimmed(result.stderr)
      if output == "" then
        output = trimmed(result.stdout)
      end
      if output == "" then
        output = "Numbat evaluation failed"
      end
      appendHistory(expr, output, true, false)
    end

    currentInput = ""
    historyIndex = nil
    draftInput = ""
    inputGeneration += 1
    isEvaluating = false
    render()
  end)
end

local function stepHistory(chord)
  if #history == 0 or isEvaluating then
    return
  end

  if chord == "up" then
    if historyIndex == nil then
      draftInput = currentInput
      historyIndex = 1
    elseif historyIndex < #history then
      historyIndex += 1
    end
    currentInput = history[#history - historyIndex + 1].expr
    inputGeneration += 1
    render()
  elseif chord == "down" then
    if historyIndex == nil then
      return
    end
    if historyIndex > 1 then
      historyIndex -= 1
      currentInput = history[#history - historyIndex + 1].expr
    else
      historyIndex = nil
      currentInput = draftInput
    end
    inputGeneration += 1
    render()
  end
end

function onInputChange(value)
  currentInput = value
  historyIndex = nil
end

function onEvaluate()
  if isEvaluating then
    return
  end
  local expr = trimmed(currentInput)
  if expr == "" then
    return
  end
  evaluate(expr)
end

function onClear()
  if isEvaluating then
    return
  end
  history = {}
  sessionExprs = {}
  currentInput = ""
  historyIndex = nil
  draftInput = ""
  previousOutputLineCount = 0
  scrollRevision += 1
  inputGeneration += 1
  render()
end

function onCopyResult(index)
  local item = history[index]
  if item == nil or not item.copyable then
    return
  end
  noctalia.copyToClipboard(item.result, "text/plain")
end

function onClose()
  panel.close()
end

function onOpen(_context)
  heldChord = nil
  heldElapsedMs = 0
  render()
end

function onKey(chord, pressed)
  if chord ~= "up" and chord ~= "down" then
    return
  end

  if pressed then
    heldChord = chord
    heldElapsedMs = 0
    panel.setNeedsFrameTick(true)
    stepHistory(chord)
  elseif heldChord == chord then
    heldChord = nil
    panel.setNeedsFrameTick(false)
  end
end

function onFrameTick(deltaMs)
  if heldChord == nil then
    return
  end

  heldElapsedMs += deltaMs
  if heldElapsedMs < REPEAT_DELAY_MS then
    return
  end

  heldElapsedMs -= REPEAT_INTERVAL_MS
  stepHistory(heldChord)
end

render()
