
local frame = CreateFrame("Frame", "AllTheSetsConfiguration", InterfaceOptionsFramePanelContainer)

local optionSpecs =
{
  interfaceShowClassIconsInList =
  {
    caption = "Show class icons in list"
  },
  interfaceShowFactionIconInList =
  {
    caption = 'Show faction icons in list'
  },
  interfaceUseClassColorsWhereUseful =
  {
    caption = 'Use class colors where available'
  },
  interfaceShowDetailsDebugText =
  {
    caption = 'Show debug text in details frame'
  }
}

frame.name = 'AllTheSets'
frame:Hide()
frame:SetScript("OnShow", function(frame)
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AllTheSets Configuration")
    
    local options = AllTheSetsGetOptions();
    
    local y, spacing = -65, 30
    for k, o in pairs(optionSpecs) do
      local checkBoxName = 'ATSCheckBox-' .. k
      local checkbox = CreateFrame("CheckButton", checkBoxName, frame, "ChatConfigCheckButtonTemplate");
      checkbox:SetPoint("TOPLEFT", 16, y)
      y = y - spacing
      
      _G[checkbox:GetName() .. 'Text']:SetText(o.caption)
      
      checkbox:SetChecked(options[k])
      checkbox:SetScript('OnClick', function()
        options[k] = checkbox:GetChecked()
      end)
    end
end)

InterfaceOptions_AddCategory(frame)

SLASH_ATS1 = '/ats'
SlashCmdList.ATS = function() 
  InterfaceOptionsFrame_OpenToCategory('AllTheSets')
  InterfaceOptionsFrame_OpenToCategory('AllTheSets')
end