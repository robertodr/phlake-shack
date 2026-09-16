--!nonstrict

local PANEL_ID = "robertodr/numbat:panel"

local function render()
  barWidget.setGlyph("calculator")
  barWidget.setTooltip("Open Numbat")
end

function update()
  render()
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onIpc(event, _payload)
  if event == "toggle" then
    noctalia.togglePanel(PANEL_ID)
  end
end

render()
