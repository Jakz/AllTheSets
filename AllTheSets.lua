----------------------
-- HELPER FUNCTIONS
----------------------

local OR, XOR, AND = 1, 3, 4

function BitwiseLeftShift(x, by)
  return x * 2 ^ by
end

function BitwiseRightShift(x, by)
  return math.floor(x / 2 ^ by)
end

function BitWiseOperation(a, b, oper)
  local r, m, s = 0, 2^52
  repeat
    s,a,b = a+b+m, a%m, b%m
    r,m = r + m*oper%(s-a-b), m/2
  until m < 1
  return r
end

function printTable(table)
  for k,v in pairs(table) do
    print('  ' .. k .. ": " .. tostring(v))
  end
end

function debug(always, text)
  if (always) then
    print(text)
  end
end

local classConstants = {
  [0x001] = 
  {
    name = 'WARRIOR',
  },
  [0x002] = 
  {
    name = 'PALADIN',
  },
  [0x004] = 
  {
    name = 'HUNTER',
  },
  [0x008] = 
  {
    name = 'ROGUE',
  },
  [0x010] = 
  {
    name = 'PRIEST',
  },
  [0x020] = 
  {
    name = 'DEATHKNIGHT',
  },
  [0x040] = 
  {
    name = 'SHAMAN',
  },
  [0x080] = 
  {
    name = 'MAGE',
  },
  [0x100] = 
  {
    name = 'WARLOCK',
  },
  [0x200] = 
  {
    name = 'MONK',
  },
  [0x400] = 
  {
    name = 'DRUID',
  },
  [0x800] = 
  {
    name = 'DEMONHUNTER',
  },
}

local EXPANSION_TABLE = {
  [0] =
  {
    ident = LE_EXPANSION_CLASSIC,
    name = 'Vanilla'
  },
  [1] =
  {
    ident = LE_EXPANSION_BURNING_CRUSADE,
    name = 'TBC'
  },
  [2] =
  {
    ident = LE_EXPANSION_WRATH_OF_THE_LICH_KING,
    name = 'WotLK'
  },
  [3] =
  {
    ident = LE_EXPANSION_CATACLYSM,
    name = 'Cataclysm'
  },
  [4] =
  {
    ident = LE_EXPANSION_MISTS_OF_PANDARIA,
    name = 'MoP'
  },
  [5] =
  {
    ident = LE_EXPANSION_WARLORDS_OF_DRAENOR,
    name = 'WoD'
  },
  [6] =
  {
    ident = LE_EXPANSION_LEGION,
    name = 'Legion'
  },
  [7] =
  {
    ident = LE_EXPANSION_BATTLE_FOR_AZEROTH,
    name = 'BfA'
  }
}

for _,v in pairs(EXPANSION_TABLE) do v.mask = BitwiseLeftShift(1, v.ident) end

local ALL_CLASSES_MASK = 0xFFF
local NO_CLASSES_MASK = 0x000

local ALL_EXPANSIONS_MASK = 0xFF
local NO_EXPANSIONS_MASK = 0x00

local BASE_SET_BUTTON_HEIGHT = 46;
local VARIANT_SET_BUTTON_HEIGHT = 20;
local SET_PROGRESS_BAR_MAX_WIDTH = 204;
local IN_PROGRESS_FONT_COLOR = CreateColor(0.251, 0.753, 0.251);
local IN_PROGRESS_FONT_COLOR_CODE = "|cff40c040";


local options = {
  filterShowCollected = true,
  filterShowNotCollected = true,
  filterClassMask = ALL_CLASSES_MASK,
  filterExpansionMask = ALL_EXPANSIONS_MASK,
  filterFactionMask =
  {
    Horde = true,
    Alliance = true
  },
  
  interfaceShowClassIcons = false
};

WardrobeSetsDataProviderMixin = {};

function WardrobeSetsDataProviderMixin:SortSets(sets, reverseUIOrder)
  local comparison = function(set1, set2)
    local groupFavorite1 = set1.favoriteSetID and true;
    local groupFavorite2 = set2.favoriteSetID and true;
    if ( groupFavorite1 ~= groupFavorite2 ) then
      return groupFavorite1;
    end
    if ( set1.favorite ~= set2.favorite ) then
      return set1.favorite;
    end
    if ( set1.uiOrder ~= set2.uiOrder ) then
      if ( reverseUIOrder ) then
        return set1.uiOrder < set2.uiOrder;
      else
        return set1.uiOrder > set2.uiOrder;
      end
    end
    return set1.setID > set2.setID;
  end

  table.sort(sets, comparison);
end

function WardrobeSetsDataProviderMixin:ResetFilterClassMask()
  local _, playerClass, _ = UnitClass('player')
  for m, c in pairs(classConstants) do
    if c.name == playerClass then
      options.filterClassMask = m
    end
  end
end

function WardrobeSetsDataProviderMixin:IsMatching(searchText, set)
  local isCollected = self:IsSetCollected(set)
  local faction = set.requiredFaction
  
  -- return set.setID == 435
    
  if ((options.filterShowCollected and isCollected) or
  (options.filterShowNotCollected and not isCollected)) and
  (BitWiseOperation(options.filterClassMask, set.classMask, AND) ~= 0) and
  (BitWiseOperation(options.filterExpansionMask, BitwiseLeftShift(1, set.expansionID), AND) ~= 0) and
  ((options.filterFactionMask.Horde and (faction == 'Horde' or faction == nil)) or
  (options.filterFactionMask.Alliance and (faction == 'Alliance' or faction == nil))) and
  (set.name:lower():match(searchText) or set.label:lower():match(searchText)) then
    return true
  end
  return false
end

function WardrobeSetsDataProviderMixin:GetBaseSets()
  if ( not self.baseSets ) then
    -- printTable(options)
    self.baseSets = {}
    C_TransmogCollection.ClearSearch(2)
    
    local allSets = C_TransmogSets.GetAllSets();
    local validIDs = { }
    
    local searchText = WardrobeCollectionFrame.searchBox:GetText()
    
    for i, set in ipairs(allSets) do
      if -- not set.baseSetID and 
      self:IsMatching(searchText, set) then
        self.baseSets[#self.baseSets + 1] = set
        validIDs[set.setID] = set
      end
    end
    
    self.variantSets = { }
    
    for i, set in ipairs(allSets) do
      
      if validIDs[set.baseSetID] ~= nil then
  
        if not self.variantSets[set.baseSetID] then
          self.variantSets[set.baseSetID] = { validIDs[set.baseSetID] }
        end

        self.variantSets[set.baseSetID][#self.variantSets[set.baseSetID] + 1] = set      
      end
    end

    
    self:DetermineFavorites();
    self:SortSets(self.baseSets);
  end
  return self.baseSets;
end

function WardrobeSetsDataProviderMixin:GetBaseSetByID(baseSetID)
  local baseSets = self:GetBaseSets();
  for i = 1, #baseSets do
    debug(true, 'getting base set for ' .. baseSetID)
    if ( baseSets[i].setID == baseSetID ) then
      return baseSets[i], i;
    end
  end
  debug(true, 'failed to find base set for ' .. baseSetID)
  return nil, nil;
end

function WardrobeSetsDataProviderMixin:GetVariantSets(baseSetID)
  if (not self.variantSets) then
    self:GetBaseSets()
  end

  return self.variantSets[baseSetID] or { };
end

function WardrobeSetsDataProviderMixin:GetSetSourceData(setID)
  if ( not self.sourceData ) then
    self.sourceData = { };
  end
  -- C_TransmogCollection.ClearSearch(2)
  local sourceData = self.sourceData[setID];
  if ( not sourceData ) then
    local isources = C_TransmogSets.GetSetSources(setID);
    local sources = {}
    
    -- GetSetSources returns always false if the current class can't equip the item
    -- that's why we need to use GetSourceInfo for real value
    for source,_ in pairs(isources) do
      local info = C_TransmogCollection.GetSourceInfo(source)
      sources[source] = info.isCollected
    end
    
    local numCollected = 0;
    local numTotal = 0;
    for sourceID, collected in pairs(sources) do
      if ( collected ) then
        numCollected = numCollected + 1;
      end
      numTotal = numTotal + 1;
    end
    sourceData = { numCollected = numCollected, numTotal = numTotal, sources = sources };
    self.sourceData[setID] = sourceData;
  end
  return sourceData;
end

function WardrobeSetsDataProviderMixin:GetSetSources(setID)
  return self:GetSetSourceData(setID).sources;
end

function WardrobeSetsDataProviderMixin:GetSetSourceCounts(setID)
  local sourceData = self:GetSetSourceData(setID);
  return sourceData.numCollected, sourceData.numTotal;
end

function WardrobeSetsDataProviderMixin:GetBaseSetData(setID)
  debug(false, 'Data::GetBaseSetData(' .. setID .. ')')
  if ( not self.baseSetsData ) then
    self.baseSetsData = { };
  end
  if ( not self.baseSetsData[setID] ) then
    local baseSetID = C_TransmogSets.GetBaseSetID(setID);
    if ( baseSetID ~= setID ) then
      return;
    end
    local topCollected, topTotal = self:GetSetSourceCounts(setID);
    local variantSets = self:GetVariantSets(setID);
    for i = 1, #variantSets do
      local numCollected, numTotal = self:GetSetSourceCounts(variantSets[i].setID);
      if ( numCollected > topCollected ) then
        topCollected = numCollected;
        topTotal = numTotal;
      end
    end
    local setInfo = { topCollected = topCollected, topTotal = topTotal, completed = (topCollected == topTotal) };
    self.baseSetsData[setID] = setInfo;
  end
  return self.baseSetsData[setID];
end

function WardrobeSetsDataProviderMixin:GetSetSourceTopCounts(setID)
  local baseSetData = self:GetBaseSetData(setID);
  if ( baseSetData ) then
    return baseSetData.topCollected, baseSetData.topTotal;
  else
    return self:GetSetSourceCounts(setID);
  end
end

function WardrobeSetsDataProviderMixin:IsBaseSetNew(baseSetID)
  local baseSetData = self:GetBaseSetData(baseSetID)
  if ( not baseSetData.newStatus ) then
    local newStatus = C_TransmogSets.SetHasNewSources(baseSetID);
    if ( not newStatus ) then
      -- check variants
      local variantSets = self:GetVariantSets(baseSetID);
      for i, variantSet in ipairs(variantSets) do
        if ( C_TransmogSets.SetHasNewSources(variantSet.setID) ) then
          newStatus = true;
          break;
        end
      end
    end
    baseSetData.newStatus = newStatus;
  end
  return baseSetData.newStatus;
end

function WardrobeSetsDataProviderMixin:ResetBaseSetNewStatus(baseSetID)
  local baseSetData = self:GetBaseSetData(baseSetID)
  if ( baseSetData ) then
    baseSetData.newStatus = nil;
  end
end

function WardrobeSetsDataProviderMixin:GetSortedSetSources(setID)
  local returnTable = { };
  local sourceData = self:GetSetSourceData(setID);
  for sourceID, collected in pairs(sourceData.sources) do
    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
    if ( sourceInfo ) then
      local sortOrder = EJ_GetInvTypeSortOrder(sourceInfo.invType);
      tinsert(returnTable, { sourceID = sourceID, collected = collected, sortOrder = sortOrder, itemID = sourceInfo.itemID, invType = sourceInfo.invType });
    end
  end

  local comparison = function(entry1, entry2)
    if ( entry1.sortOrder == entry2.sortOrder ) then
      return entry1.itemID < entry2.itemID;
    else
      return entry1.sortOrder < entry2.sortOrder;
    end
  end
  table.sort(returnTable, comparison);
  return returnTable;
end

function WardrobeSetsDataProviderMixin:IsSetCollected(set)
  return set.collected
end
  
function WardrobeSetsDataProviderMixin:ClearSets()
  self.baseSets = nil;
  self.baseSetsData = nil;
  self.variantSets = nil;
  self.usableSets = nil;
  self.sourceData = nil;
  self.collectedData = nil;
end

function WardrobeSetsDataProviderMixin:ClearBaseSets()
  self.baseSets = nil;
end

function WardrobeSetsDataProviderMixin:ClearVariantSets()
  self.variantSets = nil;
end

function WardrobeSetsDataProviderMixin:ClearUsableSets()
  self.usableSets = nil;
end

function WardrobeSetsDataProviderMixin:GetIconForSet(setID)
  local sourceData = self:GetSetSourceData(setID);
  if ( not sourceData.icon ) then
    local sortedSources = self:GetSortedSetSources(setID);
    if ( sortedSources[1] ) then
      local _, _, _, _, icon = GetItemInfoInstant(sortedSources[1].itemID);
      sourceData.icon = icon;
    else
      sourceData.icon = QUESTION_MARK_ICON;
    end
  end
  return sourceData.icon;
end

function WardrobeSetsDataProviderMixin:DetermineFavorites()
  -- if a variant is favorited, so is the base set
  -- keep track of which set is favorited
  local baseSets = self:GetBaseSets();
  for i = 1, #baseSets do
    local baseSet = baseSets[i];
    baseSet.favoriteSetID = nil;
    if ( baseSet.favorite ) then
      baseSet.favoriteSetID = baseSet.setID;
    else
      local variantSets = self:GetVariantSets(baseSet.setID);
      if (type(variantSets) == "table") then
        for j = 1, #variantSets do
          if ( variantSets[j].favorite ) then
            baseSet.favoriteSetID = variantSets[j].setID;
            break;
          end
        end
      end
    end
  end
end

function WardrobeSetsDataProviderMixin:RefreshFavorites()
  self.baseSets = nil;
  self.variantSets = nil;
  self:DetermineFavorites();
end

local SetsDataProvider = CreateFromMixins(WardrobeSetsDataProviderMixin);

--[[
name: name
label: text under name
description: type (normal, heroic, gladiator etc)
hiddenUntilCollected
setID: unique ID
expansionID: expansionID (see above)
classMask: allowed classes (see above)
collected: true/false
uiOrder: order in list, higher value = higher in list
favorite: true/false
baseSetID: unique ID of referring set (eg heroic refers to normal)
requiredFaction: Horde/Alliance/nil
]]



function ConvertClassBitMaskToStringArray(bitmask)
  local result = {}
  for i,j in pairs(classConstants) do
    if BitWiseOperation(bitmask, i, AND) ~= 0 then
      result[#result+1] = j
    end
  end
  return result
end

function ArrayToString(array)
  local result = "";
  for i,j in pairs(array) do
    result = result .. (result == "" and "" or ", ") .. j;
  end
  return result
end

function GetClassForSet(set)
  --[[
  Returns the set's class. If it belongs to more than one class,
  return an empty string.

  This is done based on the player's sex.
  Player's sex
  1 = Neutrum / Unknown
  2 = Male
  3 = Female
  ]]
  local playerSex = UnitSex("player")
  local className
  if playerSex == 2 then
    className = LOCALIZED_CLASS_NAMES_MALE[classConstants[set.classMask]]
  else
    className = LOCALIZED_CLASS_NAMES_FEMALE[classConstants[set.classMask]]
  end
  return className or ""
end

local allSets = {}
local filteredSets = {}

function CacheAllSets()
  allSets = {}
  
  for k,set in pairs(C_TransmogSets.GetAllSets()) do 
    allSets[#allSets + 1] = set
  end
  
  FilterSets(0x100)
end

function FilterSets(classMask, onlyFavorite)
  filteredSets = {}
  for k, set in pairs(allSets) do
    if classMask == nil or BitWiseOperation(classMask, set.classMask, AND) ~= 0 then
      if (not onlyFavorite or set.favorite) then
        filteredSets[#filteredSets +1 ] = set
      end
    end
  end
end

function MyWardrobeSetsCollectionMixin_SelectSet(self, setID)
  debug(true, 'selecting set ' .. setID)
  
  self.selectedSetID = setID;

  local baseSetID = C_TransmogSets.GetBaseSetID(setID);
  local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
  if ( #variantSets > 0 ) then
    self.selectedVariantSets[baseSetID] = setID;
  end

  self:Refresh();
end

function MyWardrobeSetsCollectionMixin_GetDefaultSetIDForBaseSet(self, baseSetID)
  if ( SetsDataProvider:IsBaseSetNew(baseSetID) ) then
    if ( C_TransmogSets.SetHasNewSources(baseSetID) ) then
      return baseSetID;
    else
      local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
      for i, variantSet in ipairs(variantSets) do
        if ( C_TransmogSets.SetHasNewSources(variantSet.setID) ) then
          return variantSet.setID;
        end
      end
    end
  end

  if ( self.selectedVariantSets[baseSetID] ) then
    return self.selectedVariantSets[baseSetID];
  end

  local baseSet = SetsDataProvider:GetBaseSetByID(baseSetID);
  if ( baseSet.favoriteSetID ) then
    return baseSet.favoriteSetID;
  end
  -- pick the one with most collected, higher difficulty wins ties
  local highestCount = 0;
  local highestCountSetID;
  local variantSets = SetsDataProvider:GetVariantSets(baseSetID);	
  for i = 1, #variantSets do
    local variantSetID = variantSets[i].setID;
    local numCollected = SetsDataProvider:GetSetSourceCounts(variantSetID);
    if ( numCollected > 0 and numCollected >= highestCount ) then
      highestCount = numCollected;
      highestCountSetID = variantSetID;
    end
  end
  return highestCountSetID or baseSetID;
end


function MyWardrobeSetsCollectionMixin_OnSearchUpdate(self)
  if ( self.init ) then
    SetsDataProvider:ClearBaseSets();
    SetsDataProvider:ClearVariantSets();
    SetsDataProvider:ClearUsableSets();
    self:Refresh();
  end
end

function MyWardrobeSetsCollectionMixin_DisplaySet(self, setID)
  local setInfo = (setID and C_TransmogSets.GetSetInfo(setID)) or nil;
  if ( not setInfo ) then
    self.DetailsFrame:Hide();
    self.Model:Hide();
    return;
  else
    self.DetailsFrame:Show();
    self.Model:Show();
  end

  self.DetailsFrame.Name:SetText(setInfo.name);
  if ( self.DetailsFrame.Name:IsTruncated() ) then
    self.DetailsFrame.Name:Hide();
    self.DetailsFrame.LongName:SetText(setInfo.name);
    self.DetailsFrame.LongName:Show();
  else
    self.DetailsFrame.Name:Show();
    self.DetailsFrame.LongName:Hide();
  end
  self.DetailsFrame.Label:SetText(setInfo.label .. " (" .. setInfo.setID .. ")"); -- TODO: remove id

  local newSourceIDs = C_TransmogSets.GetSetNewSources(setID);

  self.DetailsFrame.itemFramesPool:ReleaseAll();
  self.Model:Undress();
  local BUTTON_SPACE = 37;	-- button width + spacing between 2 buttons
  local sortedSources = SetsDataProvider:GetSortedSetSources(setID);
  local xOffset = -floor((#sortedSources - 1) * BUTTON_SPACE / 2);
  for i = 1, #sortedSources do
    local itemFrame = self.DetailsFrame.itemFramesPool:Acquire();
    
    itemFrame.sourceID = sortedSources[i].sourceID;
    itemFrame.itemID = sortedSources[i].itemID;
    itemFrame.collected = sortedSources[i].collected;
    itemFrame.invType = sortedSources[i].invType;
    
    local texture = C_TransmogCollection.GetSourceIcon(sortedSources[i].sourceID);
    itemFrame.Icon:SetTexture(texture);
    
    if ( sortedSources[i].collected ) then
      itemFrame.Icon:SetDesaturated(false);
      itemFrame.Icon:SetAlpha(1);
      itemFrame.IconBorder:SetDesaturation(0);
      itemFrame.IconBorder:SetAlpha(1);

      local transmogSlot = C_Transmog.GetSlotForInventoryType(itemFrame.invType);
      if ( C_TransmogSets.SetHasNewSourcesForSlot(setID, transmogSlot) ) then
        itemFrame.New:Show();
        itemFrame.New.Anim:Play();
      else
        itemFrame.New:Hide();
        itemFrame.New.Anim:Stop();
      end
    else
      itemFrame.Icon:SetDesaturated(true);
      itemFrame.Icon:SetAlpha(0.3);
      itemFrame.IconBorder:SetDesaturation(1);
      itemFrame.IconBorder:SetAlpha(0.3);
      itemFrame.New:Hide();
    end
    self:SetItemFrameQuality(itemFrame);
    itemFrame:SetPoint("TOP", self.DetailsFrame, "TOP", xOffset + (i - 1) * BUTTON_SPACE, -94);
    itemFrame:Show();
    self.Model:TryOn(sortedSources[i].sourceID);
  end
  

  -- variant sets
  local baseSetID = C_TransmogSets.GetBaseSetID(setID);
  local variantSets = SetsDataProvider:GetVariantSets(baseSetID);

  if ( #variantSets == 0 )  then
    self.DetailsFrame.VariantSetsButton:Hide();
  else
    self.DetailsFrame.VariantSetsButton:Show();
    self.DetailsFrame.VariantSetsButton:SetText(setInfo.description);
  end
end

function MyWardrobeSetsCollectionMixin_OpenVariantSetsDropDown()
  local selectedSetID = WardrobeCollectionFrame.SetsCollectionFrame:GetSelectedSetID();
  if ( not selectedSetID ) then
    return;
  end
  local info = UIDropDownMenu_CreateInfo();
  local baseSetID = C_TransmogSets.GetBaseSetID(selectedSetID);
  local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
  for i = 1, #variantSets do
    local variantSet = variantSets[i];
    local numSourcesCollected, numSourcesTotal = SetsDataProvider:GetSetSourceCounts(variantSet.setID);
    local colorCode = IN_PROGRESS_FONT_COLOR_CODE;
    if ( numSourcesCollected == numSourcesTotal ) then
      colorCode = NORMAL_FONT_COLOR_CODE;
    elseif ( numSourcesCollected == 0 ) then
      colorCode = GRAY_FONT_COLOR_CODE;
    end
    info.text = format(ITEM_SET_NAME, variantSet.description..colorCode, numSourcesCollected, numSourcesTotal);
    info.checked = (variantSet.setID == selectedSetID);
    info.func = function() WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(variantSet.setID); end;
    UIDropDownMenu_AddButton(info);
  end
end

function MyWardrobeSetsCollectionScrollFrameMixin_Update(self)
  -- local self = WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame
  
  local offset = HybridScrollFrame_GetOffset(self);
  local buttons = self.buttons;
  local baseSets = SetsDataProvider:GetBaseSets();

  -- show the base set as selected
  local selectedSetID = self:GetParent():GetSelectedSetID();
  local selectedBaseSetID = selectedSetID and C_TransmogSets.GetBaseSetID(selectedSetID);

  for i = 1, #buttons do
    local button = buttons[i];
    local setIndex = i + offset;
    if ( setIndex <= #baseSets ) then
      local baseSet = baseSets[setIndex];
      button:Show();
      button.Name:SetText(baseSet.name);
      local topSourcesCollected, topSourcesTotal = SetsDataProvider:GetSetSourceTopCounts(baseSet.setID);
      local setCollected = C_TransmogSets.IsBaseSetCollected(baseSet.setID);
      local color = IN_PROGRESS_FONT_COLOR;
      if ( setCollected ) then
        color = NORMAL_FONT_COLOR;
      elseif ( topSourcesCollected == 0 ) then
        color = GRAY_FONT_COLOR;
      end
   
      if options.interfaceShowClassIcons then
        local setClass = classConstants[baseSet.classMask]
      
        if setClass then
          local texCoords = CLASS_ICON_TCOORDS[setClass.name]      
        
          button.ClassIcon:SetTexCoord(unpack(texCoords))
          -- button.ClassIcon:SetDesaturation(0.50)
          button.ClassIcon:Show()
        else
          button.ClassIcon:Hide()
        end
      end
      
      
      button.Name:SetTextColor(color.r, color.g, color.b);
      button.Label:SetText(baseSet.label);
      button.Icon:SetTexture(SetsDataProvider:GetIconForSet(baseSet.setID));
      button.Icon:SetDesaturation((topSourcesCollected == 0) and 1 or 0);
      button.SelectedTexture:SetShown(baseSet.setID == selectedBaseSetID);
      button.Favorite:SetShown(baseSet.favoriteSetID);
      button.New:SetShown(SetsDataProvider:IsBaseSetNew(baseSet.setID));
      button.setID = baseSet.setID;

      if ( topSourcesCollected == 0 or setCollected ) then
        button.ProgressBar:Hide();
      else
        button.ProgressBar:Show();
        button.ProgressBar:SetWidth(SET_PROGRESS_BAR_MAX_WIDTH * topSourcesCollected / topSourcesTotal);
      end
      button.IconCover:SetShown(not setCollected);
    else
      button:Hide();
    end
  end

  local extraHeight = (self.largeButtonHeight and self.largeButtonHeight - BASE_SET_BUTTON_HEIGHT) or 0;
  local totalHeight = #baseSets * BASE_SET_BUTTON_HEIGHT + extraHeight;
  HybridScrollFrame_Update(self, totalHeight, self:GetHeight());
end


function MyFilterDropDown_Inizialize(self, level)
  -- like original function but we call MyFilterDropDown_InitializeBaseSets for sets drop down
  
  debug(true, "initialize dropdown ", level)
  if ( not WardrobeCollectionFrame.activeFrame ) then
    return;
  end

  if ( WardrobeCollectionFrame.activeFrame.searchType == LE_TRANSMOG_SEARCH_TYPE_ITEMS ) then
    WardrobeFilterDropDown_InitializeItems(self, level);
  elseif ( WardrobeCollectionFrame.activeFrame.searchType == LE_TRANSMOG_SEARCH_TYPE_BASE_SETS ) then
    MyFilterDropDown_InitializeBaseSets(self, level);
  end
end

function MyFilterDropDown_InitializeBaseSets(self, level)
  local refresh = function()
    SetsDataProvider:ClearBaseSets()
    SetsDataProvider:ClearVariantSets()
    SetsDataProvider:ClearUsableSets()
    WardrobeCollectionFrame.SetsCollectionFrame:Refresh()
  end
  
  local info = UIDropDownMenu_CreateInfo();
  info.keepShownOnClick = true
  
  if level == 1 then  
    info.keepShownOnClick = true;
    info.isNotRadio = true;
    info.text = COLLECTED;
    info.func = function(_, _, _, value) 
      options.filterShowCollected = value
      refresh()
    end
    info.checked = options.filterShowCollected
    UIDropDownMenu_AddButton(info, level);

    info.text = NOT_COLLECTED;
    info.func = function(_, _, _, value) 
      options.filterShowNotCollected = value 
      refresh()
    end
    info.checked = options.filterShowNotCollected
    UIDropDownMenu_AddButton(info, level);

    UIDropDownMenu_AddSeparator(1);
  
    info.checked =   nil;
    info.isNotRadio = nil;
    info.func =  nil;
    info.hasArrow = true;
    info.notCheckable = true;

    info.text = 'Classes' -- TODO: localize
    info.value = 'classes';
    UIDropDownMenu_AddButton(info, level)  
    
    info.text = 'Expansions' -- TODO: localize
    info.value = 'expansions'
    UIDropDownMenu_AddButton(info, level)  
    
    info.text = 'Factions' -- TODO: localize
    info.value = 'factions'
    UIDropDownMenu_AddButton(info, level)  
    
  elseif level == 2 then  
    
    if UIDROPDOWNMENU_MENU_VALUE == 'classes' then
    
      info.hasArrow = false;
      info.isNotRadio = true;
      info.notCheckable = false;
    
      local classNames = UnitSex('player') == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
    
      -- for each class we build the checkbox button to enable its sets
      for m,c in pairs(classConstants) do
        local texCoords = CLASS_ICON_TCOORDS[c.name]      
        info.text = classNames[c.name]
        info.icon = 'Interface\\TargetingFrame\\UI-Classes-Circles'
        info.tCoordLeft = texCoords[1]
        info.tCoordRight = texCoords[2]
        info.tCoordTop = texCoords[3]
        info.tCoordBottom = texCoords[4]
        info.colorCode = '|c' .. RAID_CLASS_COLORS[c.name].colorStr
            
        info.checked = function() return BitWiseOperation(options.filterClassMask, m, AND) ~= 0 end
        info.func = function() 
          if BitWiseOperation(options.filterClassMask, m, AND) == 0 then
            options.filterClassMask = options.filterClassMask + m
          else
            options.filterClassMask = options.filterClassMask - m
          end
          refresh()
        end
        UIDropDownMenu_AddButton(info, level)  
      end
    
      UIDropDownMenu_AddSeparator(2);
    
      info.colorCode = nil
      info.icon = nil
      info.notCheckable = true;
      info.text = CHECK_ALL
      info.func = function() 
        options.filterClassMask = ALL_CLASSES_MASK
        refresh()
        UIDropDownMenu_Refresh(self, 1, 2);
      
      end
      UIDropDownMenu_AddButton(info, level)  
    
    
      info.text = UNCHECK_ALL
      info.func = function() 
        options.filterClassMask = NO_CLASSES_MASK
        refresh()
        UIDropDownMenu_Refresh(self, 1, 2);
      end
      UIDropDownMenu_AddButton(info, level)  
    
    elseif UIDROPDOWNMENU_MENU_VALUE == 'expansions' then
      
      info.hasArrow = false;
      info.isNotRadio = true;
      info.notCheckable = false;
      
      for m,e in pairs(EXPANSION_TABLE) do
        info.text = e.name
        info.value = e
        info.func = function() 
          if BitWiseOperation(options.filterExpansionMask, e.mask, AND) == 0 then
            options.filterExpansionMask = options.filterExpansionMask + e.mask
          else
            options.filterExpansionMask = options.filterExpansionMask - e.mask
          end
          refresh()
        end
        info.checked = function() return BitWiseOperation(options.filterExpansionMask, e.mask, AND) ~= 0 end
        UIDropDownMenu_AddButton(info, level)    
      end
      
      UIDropDownMenu_AddSeparator(2);
    
      info.colorCode = nil
      info.icon = nil
      info.notCheckable = true;
      info.text = CHECK_ALL
      info.func = function() 
        options.filterExpansionMask = ALL_EXPANSIONS_MASK
        refresh()
        UIDropDownMenu_Refresh(self, 1, 2);
      
      end
      UIDropDownMenu_AddButton(info, level)  
    
    
      info.text = UNCHECK_ALL
      info.func = function() 
        options.filterExpansionMask = NO_EXPANSIONS_MASK
        refresh()
        UIDropDownMenu_Refresh(self, 1, 2);
      end
      UIDropDownMenu_AddButton(info, level)  
    
    elseif UIDROPDOWNMENU_MENU_VALUE == 'factions' then
      
      info.hasArrow = false;
      info.isNotRadio = true;
      info.notCheckable = false;
      
      info.text = 'Alliance' -- TODO:localize
      info.icon = 'Interface\\Timer\\Alliance-Logo'
      info.checked = function() return options.filterFactionMask.Alliance end
      info.func = function(_, _, _, value) 
        options.filterFactionMask.Alliance = value
        refresh()
      end
      UIDropDownMenu_AddButton(info, level)  
    
      info.text = 'Horde' -- TODO:localize
      info.icon = 'Interface\\Timer\\Horde-Logo'
      info.checked = function() return options.filterFactionMask.Horde end
      info.func = function(_, _, _, value) 
        options.filterFactionMask.Horde = value 
        refresh()
      end
      UIDropDownMenu_AddButton(info, level)  
         
    end
  end

  --[[ info = UIDropDownMenu_CreateInfo();
  info.keepShownOnClick = true;
  info.isNotRadio = true;

  info.text = TRANSMOG_SET_PVE;
  info.func = function(_, _, _, value)
  C_TransmogSets.SetBaseSetsFilter(LE_TRANSMOG_SET_FILTER_PVE, value);
  end 
  info.checked = C_TransmogSets.GetBaseSetsFilter(LE_TRANSMOG_SET_FILTER_PVE);
  UIDropDownMenu_AddButton(info, level);

  info.text = TRANSMOG_SET_PVP;
  info.func = function(_, _, _, value)
  C_TransmogSets.SetBaseSetsFilter(LE_TRANSMOG_SET_FILTER_PVP, value);
  end 
  info.checked = C_TransmogSets.GetBaseSetsFilter(LE_TRANSMOG_SET_FILTER_PVP);
  UIDropDownMenu_AddButton(info, level); ]]
end

local frame = CreateFrame("frame", "AllTheSetsFrame");
local function onEvent(self, event, ...)
  if (event == "PLAYER_LOGIN") then
    print("AllTheSets 0.1 loaded");   
    if IsAddOnLoaded("Blizzard_Collections") then
      onEvent(self, "ADDON_LOADED", "Blizzard_Collections");
    else
      self:RegisterEvent("ADDON_LOADED")
    end  
  elseif (event == "ADDON_LOADED" and select(1, ...) == "AllTheSets") then
    if ATSRepository == nil then
      ATSRepository = 'antani'
    end
  elseif (event == "ADDON_LOADED" and select(1, ...) == "Blizzard_Collections") then
    -- self:UnregisterEvent("ADDON_LOADED");
    print "Registering hooks for AllTheSets";

    -- WardrobeCollectionFrame.SetsTransmogFrame
    -- WardrobeCollectionFrame.FilterButton:SetEnabled(false);
    
    SetsDataProvider:ResetFilterClassMask()

        
    WardrobeCollectionFrame.SetsCollectionFrame:HookScript("OnShow", 
    function(self) 
      -- WardrobeCollectionFrame.SetsCollectionFrame.baseSets = {} -- C_TransmogSets.GetAllSets();
        
      --[[ for k,v in pairs(WardrobeCollectionFrame.SetsCollectionFrame:GetBaseSets()) do 
      print(k, v);
      end ]]--
        
      local backdrop = {
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
        insets = { left = 4, right = 3, top = 4, bottom = 3 }
      }

      local function ScrollframeOnSizeChanged(frame, width, height)
        frame:GetScrollChild():SetWidth(width)
      end

      local box = CreateFrame("frame", nil, UIParent)
      box:SetWidth(300)
      box:SetHeight(200)
      box:SetBackdrop(backdrop)
      box:SetBackdropColor(0, 0, 0)
      box:SetBackdropBorderColor(0.4, 0.4, 0.4)
      box:SetPoint("CENTER")

      box:SetMovable(true);
      box:RegisterForDrag("LeftButton")
      box:SetScript("OnDragStart", frame.StartMoving)
      box:SetScript("OnDragStop", frame.StopMovingOrSizing)
        
      box.scrollBar = CreateFrame("ScrollFrame", "scollName", box, "UIPanelScrollFrameTemplate")
      box.scrollBar:SetPoint("TOPLEFT", box, 5, -5)
      box.scrollBar:SetPoint("BOTTOMRIGHT", box, -26, 4)
      box.scrollBar:EnableMouse(true)

      local content = CreateFrame("frame", nil, box.scrollBar)
      content:SetSize(box.scrollBar:GetWidth(), 0)
      content:SetPoint("TOPLEFT", box, 5, -5)
      content:SetPoint("BOTTOMRIGHT", box, -26, 4)
      content:EnableMouse(true)
        
      box.content = content;
      box.scrollBar:SetScrollChild(box.content);
      box.scrollBar:SetScript("OnSizeChanged", ScrollframeOnSizeChanged)

      box.content.text = box:CreateFontString(nil, "ARTWORK") 
      box.content.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
      box.content.text:SetPoint("TOPLEFT", 5, -5)
      box.content.text:SetPoint("TOPRIGHT", 5, -5)
      box:Hide()
  
      CacheAllSets()
      FilterSets(nil, false)
        
      --[[local string = ""
      for k,v in pairs(filteredSets) do 
      string = string .. v.name .. " " .. v.setID .. " -- " .. ArrayToString(ConvertClassBitMaskToStringArray(v.classMask)) .. '\n'; 
      end
      box.content.text:SetText(string); ]]
        
      -- WardrobeCollectionFrame.SetsCollectionFrame:DisplaySet(203)
      -- WardrobeCollectionFrame.SetsCollectionFrame:Refresh()
              
      -- WardrobeCollectionFrame.FilterButton:SetEnabled(false);
      --[[ for i,j in pairs(WardrobeCollectionFrame.SetsCollectionFrame) do
      print(i, " = ", j);            
      end]]
        
      --[[
      Blizzard UI sets frame has a design flaw: the data provider for all the sets is an hidden local
      variable which cannot be replaced. This means that all methods of the WadrobeSetsCollectionMixin
      which use SetsDataProvider must be replaced with new method which uses our implementation
        
      Things may change if UI code changes but there are the involved methods at the moment:
      OnShow() (we can HookScript)
      OnHide() (we can HookScript)
      DisplaySet(setID)
          
      ]]
        

      WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame['update'] = MyWardrobeSetsCollectionScrollFrameMixin_Update
      WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame['Update'] = MyWardrobeSetsCollectionScrollFrameMixin_Update
        
      local buttons = WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame.buttons       
      for i = 1, #buttons do
        local button = buttons[i];
        button.ClassIcon = button:CreateTexture(nil, "BACKGROUND")
        button.ClassIcon:SetPoint("TOPRIGHT", -1, -2);
        button.ClassIcon:SetTexture('Interface\\TargetingFrame\\UI-Classes-Circles')
        -- buttons.classIcon:SetTexCoord(0, 0.25, 0, 0.25)
        button.ClassIcon:SetSize(20, 20)
        button.ClassIcon:Hide()
      end

      -- replace functions of SetsCollectionFrame with addon custom functions
      WardrobeCollectionFrame.SetsCollectionFrame['SelectSet'] = MyWardrobeSetsCollectionMixin_SelectSet
      WardrobeCollectionFrame.SetsCollectionFrame['GetDefaultSetIDForBaseSet'] = MyWardrobeSetsCollectionMixin_GetDefaultSetIDForBaseSet
      WardrobeCollectionFrame.SetsCollectionFrame['DisplaySet'] = MyWardrobeSetsCollectionMixin_DisplaySet      
      WardrobeCollectionFrame.SetsCollectionFrame['OnSearchUpdate'] = MyWardrobeSetsCollectionMixin_OnSearchUpdate

      -- WardrobeCollectionFrame.searchBox
      printTable(WardrobeCollectionFrame.FilterDropDown)
        
      -- Replacing initialization of filter drop down menu with our own custom function
      UIDropDownMenu_Initialize(WardrobeCollectionFrame.FilterDropDown, MyFilterDropDown_Inizialize, "MENU")
        
      UIDropDownMenu_Initialize(WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.VariantSetsDropDown, MyWardrobeSetsCollectionMixin_OpenVariantSetsDropDown, "MENU")
        
      print "Showing menu"; 
    end
  );
    
  WardrobeCollectionFrame.SetsCollectionFrame:HookScript("OnHide", function(self) print "Hiding menu"; end)
    
    
  -- print(WardrobeFilterDropDown);
    
  --[[ local info = WardrobeFilterDropDown;
  info.keepShownOnClick = true;
  info.isNotRadio = false;

  info.text = 'Warrior';
  info.checked = true
    
  UIDropDownMenu_AddButton(WardrobeFilterDropDown, 1); ]]--
    
  --[[ local optionsButton = CreateFrame("Button", nil, WardrobeCollectionFrame)
  optionsButton:SetPoint("TOPRIGHT", WardrobeCollectionFrameWeaponDropDown, -75, -28)
  optionsButton:SetSize(31,31)
  optionsButton:SetScript("OnClick", ButtonOnClick)
  optionsButton:SetScript("OnEnter", ButtonOnEnter)
  optionsButton:SetScript("OnLeave", ButtonOnLeave)
  optionsButton.tooltip = "Options"

  optionsButton.Texture = optionsButton:CreateTexture(nil,"ARTWORK")
  optionsButton.Texture:SetPoint("CENTER")
  optionsButton.Texture:SetSize(28,28)
  optionsButton.Texture:SetAtlas("Class") ]]
end
    
end
frame:SetScript("OnEvent", onEvent)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")


--[[ local function Neutralizer(box)
box:SetParent(UIParent)
box.scrollbar:SetValue(0)
box:Hide()
end ]]--


