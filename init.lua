

-- hs.loadSpoon("ClipboardTool")

-- spoon.ClipboardTool.show_copied_alert = false
-- spoon.ClipboardTool.hist_size = 100
-- spoon.ClipboardTool:start()


-- Constants
CMD_CHECK_DELAY = 0.4  -- How long between cmd presses to consider it a double-tap
MODIFIERS = {"cmd"}    -- Modifiers used for app shortcuts
MISSION_CONTROL_DELAY = CMD_CHECK_DELAY

-- App configuration
APPS = {
  {shortcut = "1", name = "Terminal"},
  {shortcut = "2", name = "Visual Studio Code"},
  -- {shortcut = "2", name = "Publii"},  
  -- {shortcut = "2", name = "Autodesk Fusion"},

  {shortcut = "3", name = "Google Chrome"},
  {shortcut = "4", name = "Slack"},
  {shortcut = "5", name = "Finder"},
  {shortcut = "7", name = "Spotify"},
  {shortcut = "b", name = "ChatGPT"},
}

-- Bind application shortcuts
for _, app in ipairs(APPS) do
  hs.hotkey.bind(MODIFIERS, app.shortcut, function()
    hs.application.launchOrFocus(app.name)
  end)
end


-- State variables
lastFlags = {}
lastCmdPressTime = 0
expectingSecondCmd = false

-- Event handler for flag changes (modifier keys)
function flagsChangeHandler(event)
  local currentFlags = event:getFlags()
  
  local now = hs.timer.secondsSinceEpoch()

  -- When Cmd is pressed down (and wasn't before)
  if currentFlags.cmd and not lastFlags.cmd then
    -- Check if this is a second press within the defined delay
    if expectingSecondCmd and (now - lastCmdPressTime) <= MISSION_CONTROL_DELAY then
      -- Double-tap detected: open Mission Control immediately
      hs.spaces.openMissionControl()
      -- Reset state
      expectingSecondCmd = false
    else
      -- First Cmd press recorded, now waiting for a potential second press
      expectingSecondCmd = true
      lastCmdPressTime = now
    end
  end

  -- If cmd is released, and no double-tap has occurred yet,
  -- just continue waiting. The next cmd press might form a double-tap.

  -- If any other modifiers are pressed along with cmd, this should cancel the double-tap expectation.
  if currentFlags.alt or currentFlags.shift or currentFlags.ctrl or currentFlags.fn then
    expectingSecondCmd = false
  end

  lastFlags = currentFlags
end

-- Event handler for normal key presses
function keyDownHandler(event)
  local currentFlags = event:getFlags()
  
  -- If any non-modifier key is pressed while we are expecting a second cmd tap,
  -- cancel the double-tap expectation.
  if expectingSecondCmd and currentFlags.cmd then
    expectingSecondCmd = false
  end

  return false
end

-- Create and start the event taps
flagsEventTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, flagsChangeHandler)
flagsEventTap:start()

keyDownEventTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, keyDownHandler)
keyDownEventTap:start()

-- Reverse map for key codes to key names (optional for debugging)
keyFromCode = {}
for keyName, keyCode in pairs(hs.keycodes.map) do
    keyFromCode[keyCode] = keyName
end

-- Create an event tap for keyDown and keyUp events
controlToCommandTap = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(evt)
        -- Get the frontmost application
        local frontmostApp = hs.application.frontmostApplication()

        -- If Terminal is frontmost, do not modify the event
        if frontmostApp and frontmostApp:name() == "Terminal" then
            return false
        end

        local flags = evt:getFlags()

        -- If the event includes the Control key, transform it into a Command key press
        if flags.ctrl then
            flags.ctrl = nil    -- remove ctrl flag
            flags.cmd = true    -- add cmd flag
            evt:setFlags(flags)

            -- Suppress the original event and return the modified one
            return true, {evt}
        end

        return false
    end
)

controlToCommandTap:start()
