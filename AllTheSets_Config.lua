
local frame = CreateFrame("Frame", "AllTheSetsConfiguration", InterfaceOptionsFramePanelContainer)

local optionSpecs =
{
  {
    ident = 'interfaceShowClassIconsInList',
    caption = 'Show class icons in list'
  },
  {
    ident = 'interfaceShowFactionIconInList',
    caption = 'Show faction icons in list'
  },
  {
    ident = 'interfaceUseClassColorsWhereUseful',
    caption = 'Use class colors where available'
  },
  {
    ident = 'saveFilter',
    caption = 'Save filter between sessions'
  },
  {
    ident = 'interfaceShowDetailsDebugText',
    caption = 'Show debug text in details frame'
  }
}

local countModes = { 
  {
    value = 'None',
    caption = 'None'
  },
  {
    value = 'TopSource',
    caption = 'Show top variant'
  },
  {
    value = 'AllSources',
    caption = 'Show all variants'
  }
}

local loaded = false

frame.name = 'AllTheSets'
frame:Hide()
frame:SetScript("OnShow", function(frame)
  if loaded then return --TODO: OnLoad doesn't seem to work
  else loaded = true
  end
  
  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("AllTheSets Configuration")
    
  local options = AllTheSetsGetOptions();
    
  local y, spacing = -65, 30
  for k, o in pairs(optionSpecs) do
    local checkBoxName = 'ATSCheckBox-' .. o.ident
    local checkbox = CreateFrame("CheckButton", checkBoxName, frame, "ChatConfigCheckButtonTemplate");
    checkbox:SetPoint("TOPLEFT", 16, y)
    y = y - spacing
      
    _G[checkbox:GetName() .. 'Text']:SetText(o.caption)
      
    checkbox:SetChecked(options[o.ident])
    checkbox:SetScript('OnClick', function()
      options[o.ident] = checkbox:GetChecked()
    end)
  end
  
  -- count tooltip in group drop down
  do
    y = y - 6
  
    local completonTooltipLabel = frame:CreateFontString("Completion tooltip mode:", ARTWORK, "GameFontWhite")
    completonTooltipLabel:SetPoint("TOPLEFT", 16, y)
    completonTooltipLabel:SetText("Completion tooltip mode:")
  
    local setCountModeInGroupDropDown = CreateFrame("frame", nil, frame, "UIDropDownMenuTemplate")
    setCountModeInGroupDropDown:SetPoint('TOPLEFT', completonTooltipLabel, 'TOPRIGHT', 0, 6)
    
    local SetDropDownText = function(v)
      for _,m in pairs(countModes) do
        if (m.value == v) then
          UIDropDownMenu_SetText(setCountModeInGroupDropDown, m.caption)
        end      
      end
    end
    
    UIDropDownMenu_SetWidth(setCountModeInGroupDropDown, 120)
    SetDropDownText(options.interfaceCompletionStatusInGroupDropDown)
    UIDropDownMenu_Initialize(setCountModeInGroupDropDown, function(self, level)
      local info = UIDropDownMenu_CreateInfo()
      
      local func = function(i,_,_,_)
        options.interfaceCompletionStatusInGroupDropDown = i.value
        SetDropDownText(i.value)
      end
      
      for _,m in pairs(countModes) do
        info.text = m.caption
        info.value = m.value
        info.checked = m.value == options.interfaceCompletionStatusInGroupDropDown 
        info.func = func
        UIDropDownMenu_AddButton(info, level)
      end  
    end)
  end
end)

InterfaceOptions_AddCategory(frame)

SLASH_ATS1 = '/ats'
SlashCmdList.ATS = function() 
  InterfaceOptionsFrame_OpenToCategory('AllTheSets')
  InterfaceOptionsFrame_OpenToCategory('AllTheSets')
end