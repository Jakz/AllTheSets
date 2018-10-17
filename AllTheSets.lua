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
  filterShowHiddenByDefault = false,
  filterShowPvP = true,
  filterShowPvE = true,
  filterClassMask = ALL_CLASSES_MASK,
  filterExpansionMask = ALL_EXPANSIONS_MASK,
  filterFactionMask =
  {
    Horde = true,
    Alliance = true
  },
  
  interfaceShowClassIconsInList = false,
  interfaceShowDetailsDebugText = true
};

local function ResetSearchFilter()
  options.filterShowCollected = true
  options.filterShowNotCollected = true
  options.filterShowHiddenByDefault = false

  options.filterShowPvP = true
  options.filterShowPvE = true
  
  options.filterExpansionMask = ALL_EXPANSIONS_MASK
  
  local _, playerClass, _ = UnitClass('player')
  for m, c in pairs(classConstants) do
    if c.name == playerClass then
      options.filterClassMask = m
    end
  end
  
  local _, playerFaction = UnitFactionGroup('player')
  if (playerFaction == 'Horde') then -- TODO: make generic with some Blizzard constant?
    options.filterFactionMask.Horde = true
    options.filterFactionMask.Alliance = false
  elseif (playerFaction == 'Alliance') then -- TODO: make generic with some Blizzard constant?
    options.filterFactionMask.Horde = false
    options.filterFactionMask.Alliance = true
  else
    options.filterFactionMask.Horde = true
    options.filterFactionMask.Alliance = true
  end
end

MyDataProvider = {};

function MyDataProvider:SortSets(sets, reverseUIOrder)
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

function MyDataProvider:IsMatching(searchText, set)
  local isCollected = self:IsSetCollected(set)
  local faction = set.requiredFaction
  
  local isPvpPveMatching = 
    (options.filterShowPvP and options.filterShowPvE) or 
    (set.label:match("Season") and options.filterShowPvP) or
    (not set.label:match("Season") and options.filterShowPvE)

  
  -- return set.setID == 818
  --return set.label == 'Firelands'
    
  -- this is the main filtering function which takes into account all the options set in the frame
  if ((options.filterShowCollected and isCollected) or
  (options.filterShowNotCollected and not isCollected)) and
  
  (BitWiseOperation(options.filterClassMask, set.classMask, AND) ~= 0) and
  
  (BitWiseOperation(options.filterExpansionMask, BitwiseLeftShift(1, set.expansionID), AND) ~= 0) and
  
  (options.filterShowHiddenByDefault or not set.hiddenUntilCollected) and
  
  ((options.filterFactionMask.Horde and (faction == 'Horde' or faction == nil)) or
  (options.filterFactionMask.Alliance and (faction == 'Alliance' or faction == nil))) and
  
  isPvpPveMatching and
  
  (set.name:lower():match(searchText) or set.label:lower():match(searchText)) 
  
  then
    return true
  end
  return false
end

function MyDataProvider:CacheSets()
  if (not self.sets) then
    self.sets = { }
  end
  
  C_TransmogCollection.ClearSearch(2)
  local allSets = C_TransmogSets.GetAllSets();
  
  for i, set in ipairs(allSets) do
    self.sets[set.setID] = set
  end

end

function MyDataProvider:GetBaseSets()  
  if ( not self.baseSets ) then
    debug(true, 'caching sets')
    self.baseSets = {}
    C_TransmogCollection.ClearSearch(2)
    
    local allSets = C_TransmogSets.GetAllSets();
    local validIDs = { }
    
    local searchText = WardrobeCollectionFrame.searchBox:GetText()
    
    -- if set is matching current filter add it to list and map its id
    for i, set in ipairs(allSets) do
      if not set.baseSetID and 
      self:IsMatching(searchText, set) then       
        set.singleClass = classConstants[set.classMask]    
        
        self.baseSets[#self.baseSets + 1] = set
        validIDs[set.setID] = set
      end
    end
    
    self.variantSets = { }
    
    -- compute variants list by storing all sets which has baseSetID of a matching set
    for i, set in ipairs(allSets) do     
      -- if validIDs[set.baseSetID] ~= nil then
      if set.baseSetID then
        if not self.variantSets[set.baseSetID] then
          self.variantSets[set.baseSetID] = { validIDs[set.baseSetID] }
        end
        self.variantSets[set.baseSetID][#self.variantSets[set.baseSetID] + 1] = set      
      end
      -- end
    end
    
    -- compute all sets which exist for multiple classes by using the label description to match them
    self.setsByPlace = { }  
    for i, set in ipairs(allSets) do
      if set.label and not set.baseSetID then
        if not self.setsByPlace[set.label] then
          self.setsByPlace[set.label] = { }
        end
      
        self.setsByPlace[set.label][#self.setsByPlace[set.label] + 1] = set
      end
    end
    
    -- sort variants by uiOrder
    for _, variants in pairs(self.variantSets) do
      table.sort(variants, function(s1, s2)
        return s1.uiOrder < s2.uiOrder
      end)
    end
            
    self:DetermineFavorites();
    self:SortSets(self.baseSets);
  end
  return self.baseSets;
end

function MyDataProvider:GetSetsByPlace(label)
  if not self.setsByPlace then
    self:GetBaseSets()
  end
  return self.setsByPlace[label] or { }
end

function MyDataProvider:GetBaseSetByID(baseSetID)
  local baseSets = self:GetBaseSets();
  for i = 1, #baseSets do
    debug(false, 'getting base set for ' .. baseSetID)
    if ( baseSets[i].setID == baseSetID ) then
      return baseSets[i], i;
    end
  end
  debug(false, 'failed to find base set for ' .. baseSetID)
  return nil, nil;
end

function MyDataProvider:GetVariantSets(baseSetID)
  if (not self.variantSets) then
    self:GetBaseSets()
  end

  return self.variantSets[baseSetID] or { };
end

function MyDataProvider:GetAllSourcesData(setID)
  local isources = C_TransmogSets.GetSetSources(setID);
  
  local data = {}
  
  -- for each set source
  for source,_ in pairs(isources) do
    -- we get all equivalent appearances for that item
    local info = C_TransmogCollection.GetSourceInfo(source)
    local allSourcesForItem = C_TransmogCollection.GetAllAppearanceSources(info.visualID)
    local sourceData = { #allSourcesForItem, 0}
    
    -- for all such appearances we count how many are collected and the total
    for k,v in pairs(allSourcesForItem) do
      local singleSourceInfo = C_TransmogCollection.GetSourceInfo(v)
    
      if singleSourceInfo.isCollected then
        sourceData[2] = sourceData[2] + 1
      end
    end
    
    data[#data + 1] = sourceData
  end
  
  return data
end

function MyDataProvider:GetSetSourceData(setID)
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
      --[[local info = C_TransmogCollection.GetSourceInfo(source)
      sources[source] = info.isCollected]]
      local info = C_TransmogCollection.GetSourceInfo(source)
       local allSourcesForItem = C_TransmogCollection.GetAllAppearanceSources(info.visualID)
   
       sources[source] = false
       for k,v in pairs(allSourcesForItem) do
      
          local singleSourceInfo = C_TransmogCollection.GetSourceInfo(v)
      
          if singleSourceInfo.isCollected then
             sources[source] = true
          end
       end
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

function MyDataProvider:GetSetSources(setID)
  return self:GetSetSourceData(setID).sources;
end

function MyDataProvider:GetSetSourceCounts(setID)
  local sourceData = self:GetSetSourceData(setID);
  return sourceData.numCollected, sourceData.numTotal;
end

function MyDataProvider:GetBaseSetData(setID)
  debug(false, 'Data::GetBaseSetData(' .. setID .. ')')
  if ( not self.baseSetsData ) then
    self.baseSetsData = { };
  end
  if ( not self.baseSetsData[setID] ) then
    local baseSetID = C_TransmogSets.GetBaseSetID(setID);
    if ( baseSetID ~= setID ) then
      debug(true, "set for " .. setID .. "is not base (" .. baseSetID .. " is base)")
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

function MyDataProvider:GetSetSourceTopCounts(setID)
  local baseSetData = self:GetBaseSetData(setID);
  if ( baseSetData ) then
    return baseSetData.topCollected, baseSetData.topTotal;
  else
    return self:GetSetSourceCounts(setID);
  end
end

function MyDataProvider:IsBaseSetNew(baseSetID)
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

function MyDataProvider:ResetBaseSetNewStatus(baseSetID)
  local baseSetData = self:GetBaseSetData(baseSetID)
  if ( baseSetData ) then
    baseSetData.newStatus = nil;
  end
end

function MyDataProvider:GetSortedSetSources(setID)
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

function MyDataProvider:IsSetCollected(set)
  return set.collected
end
  
function MyDataProvider:ClearSets()
  debug(true, 'clearing sets')
  
  self.baseSets = nil;
  self.baseSetsData = nil;
  self.variantSets = nil;
  self.usableSets = nil;
  self.sourceData = nil;
  self.setsByPlace = nil;
  
  
  self.collectedData = nil;
end

function MyDataProvider:ClearBaseSets()
  self.baseSets = nil;
end

function MyDataProvider:ClearVariantSets()
  self.variantSets = nil;
end

function MyDataProvider:ClearUsableSets()
  self.usableSets = nil;
end

function MyDataProvider:GetIconForSet(setID)
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

function MyDataProvider:DetermineFavorites()
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

local SetsDataProvider = CreateFromMixins(MyDataProvider);

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
  
  self.DetailsFrame.Label:SetText(setInfo.label)
  
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
  
  -- class drop down
  if self.DetailsFrame.ClassChoiceButton then
    local setsForPlace = SetsDataProvider:GetSetsByPlace(setInfo.label)
    if (setsForPlace and #setsForPlace > 1) then
      self.DetailsFrame.ClassChoiceButton:Show()
      
      local class = classConstants[setInfo.classMask].name
      local classNames = UnitSex('player') == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
      local color = RAID_CLASS_COLORS[class]
      
      self.DetailsFrame.ClassChoiceButton:SetText(classNames[class])
      self.DetailsFrame.ClassChoiceButton:GetFontString():SetTextColor(color.r, color.g, color.b, 1.0)
    else
      self.DetailsFrame.ClassChoiceButton:Hide()
    end
  end
  
  -- debug string
  if options.interfaceShowDetailsDebugText then
    local sources = SetsDataProvider:GetSortedSetSources(setID);
    local sourceData = MyDataProvider:GetAllSourcesData(setID);
 
    local string = 
    'ID: ' .. setInfo.setID .. '\n' ..
    'baseID: ' .. baseSetID .. '\n' ..
    'variants: ' .. #variantSets .. '\n' ..
    'uiOrder: ' .. setInfo.uiOrder .. '\n' ..
    'pieces: ' .. #sourceData .. '\n' ..
    'sources: '
    
    for _,data in ipairs(sourceData) do
      string = string .. ' ' .. (data[2] > 0 and '|cff80ff80' or '|cffff8080') .. data[1]
    end
    
    self.DetailsFrame.DebugString:SetText(string)
    self.DetailsFrame.DebugString:Show()
  else
    self.DetailsFrame.DebugString:Hide()
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
      local setCollected = topSourcesCollected == topSourcesTotal
      local color = IN_PROGRESS_FONT_COLOR;
      if ( setCollected ) then
        color = NORMAL_FONT_COLOR;
      elseif ( topSourcesCollected == 0 ) then
        color = GRAY_FONT_COLOR;
      end
   
      if options.interfaceShowClassIconsInList then
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

function UI_DecorateDropDownItemForClass(info, class)
  local classNames = UnitSex('player') == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
  local texCoords = CLASS_ICON_TCOORDS[class]      
  
  info.text = classNames[class]
  info.icon = 'Interface\\TargetingFrame\\UI-Classes-Circles'
  info.tCoordLeft = texCoords[1]
  info.tCoordRight = texCoords[2]
  info.tCoordTop = texCoords[3]
  info.tCoordBottom = texCoords[4]
  info.colorCode = '|c' .. RAID_CLASS_COLORS[class].colorStr
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
    
    info.text = 'PvE';
    info.func = function(_, _, _, value) 
      options.filterShowPvE = value 
      refresh()
    end
    info.checked = options.filterShowPvE
    UIDropDownMenu_AddButton(info, level);
    
    info.text = 'PvP';
    info.func = function(_, _, _, value) 
      options.filterShowPvP = value 
      refresh()
    end
    info.checked = options.filterShowPvP
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
    
    UIDropDownMenu_AddSeparator(1);
    
    -- Hidden by default checkbox 
    info.isNotRadio = true
    info.hasArrow = false
    info.notCheckable = false
    info.text = 'Show hidden by default'; -- TODO: localize
    info.func = function(_, _, _, value) 
      options.filterShowHiddenByDefault = value 
      refresh()
    end
    info.checked = options.filterShowHiddenByDefault
    UIDropDownMenu_AddButton(info, level);
    
    -- Reset filter button
    info.notCheckable = true
    info.text = 'Reset default filter' -- TODO: localize
    info.func = function(_, _, _, value) 
      ResetSearchFilter();
      UIDropDownMenu_Refresh(self, 1, 1);
      refresh()
    end
    UIDropDownMenu_AddButton(info, level);
    
    
  elseif level == 2 then  
    
    if UIDROPDOWNMENU_MENU_VALUE == 'classes' then
    
      info.hasArrow = false;
      info.isNotRadio = true;
      info.notCheckable = false;
    
      -- for each class we build the checkbox button to enable its sets
      for m,c in pairs(classConstants) do
        UI_DecorateDropDownItemForClass(info, c.name)
            
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
end

local function EnhanceBlizzardUI()
  local DetailsFrame = WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame
 
  -- Class choice drop down button
  DetailsFrame.ClassChoiceButton = CreateFrame("button", 'ClassChoiceButton', DetailsFrame, 'UIMenuButtonStretchTemplate')
  DetailsFrame.ClassChoiceButton:SetSize(108, 22)
  DetailsFrame.ClassChoiceButton:SetPoint("TOPLEFT", 6, -6)
  DetailsFrame.ClassChoiceButton:SetScript('OnClick', function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		ToggleDropDownMenu(1, nil, DetailsFrame.ClassChoiceDropDown, DetailsFrame.ClassChoiceButton:GetName(), 0, 1);
  end)

  local triangleIcon = DetailsFrame.ClassChoiceButton:CreateTexture(nil, "ARTWORK")
  triangleIcon:SetPoint('LEFT', DetailsFrame.ClassChoiceButton, 'LEFT', 5, -2)
  triangleIcon:SetAtlas('friendslist-categorybutton-arrow-down', true)
  
  -- Class choice drop down menu
  do
    DetailsFrame.ClassChoiceDropDown = CreateFrame("frame", nil, UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(DetailsFrame.ClassChoiceDropDown, 200)
    
    local initialization = function(self, level)
      local info = UIDropDownMenu_CreateInfo()
      info.keepShownOnClick = false
      
      local setID = WardrobeCollectionFrame.SetsCollectionFrame:GetSelectedSetID()
      local setInfo = C_TransmogSets.GetSetInfo(setID)
      local setsForPlace = SetsDataProvider:GetSetsByPlace(setInfo.label)
      for m,c in pairs(classConstants) do
        local setForClass = nil
        for _,s in pairs(setsForPlace) do
          if m == s.classMask then
            setForClass = s
          end
        end
        
        if setForClass then        
          UI_DecorateDropDownItemForClass(info, c.name)
            
          info.checked = function() 
            return setInfo.classMask == m
          end
          
          info.func = function() 
            WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(setForClass.setID)
            refresh()
          end
          UIDropDownMenu_AddButton(info, level)          
        end
      end
    end
        
    UIDropDownMenu_Initialize(DetailsFrame.ClassChoiceDropDown, initialization, "MENU")
  end
  
   
  -- Debug String  
  DetailsFrame.DebugString = DetailsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  DetailsFrame.DebugString:SetJustifyH("LEFT")
  DetailsFrame.DebugString:SetSize(200,100)
  DetailsFrame.DebugString:SetPoint("BOTTOMLEFT", 10, 0)
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
    
    ResetSearchFilter()

        
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
        
      EnhanceBlizzardUI()
        
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
      -- printTable(WardrobeCollectionFrame.FilterDropDown)
        
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


