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
    print("|cffff8000AllTheSets|cffffffff: ", text)
  end
end

local COLORS = {
  white = '|cffffffff'
}

local ALL_CLASSES_MASK = 0xFFF
local NO_CLASSES_MASK = 0x000
local PLATE_CLASSES_MASK = 0x001 + 0x002 + 0x020
local MAIL_CLASSES_MASK = 0x004 + 0x040
local LEATHER_CLASSES_MASK = 0x008 + 0x200 + 0x400 + 0x800
local CLOTH_CLASSES_MASK = 0x010 + 0x080 + 0x100

local armorClassConstants = { -- TODO: localize
  [PLATE_CLASSES_MASK] = {
    name = 'Plate'
  }, 
  [MAIL_CLASSES_MASK] = {
    name = 'Mail'
  },
  [LEATHER_CLASSES_MASK] = {
    name = 'Leather'
  },
  [CLOTH_CLASSES_MASK] = {
    name = 'Cloth'
  } 
}

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

local ALL_EXPANSIONS_MASK = 0xFF
local NO_EXPANSIONS_MASK = 0x00

local BASE_SET_BUTTON_HEIGHT = 46;
local VARIANT_SET_BUTTON_HEIGHT = 20;
local SET_PROGRESS_BAR_MAX_WIDTH = 204;
local IN_PROGRESS_FONT_COLOR = CreateColor(0.251, 0.753, 0.251);
local IN_PROGRESS_FONT_COLOR_CODE = "|cff40c040";

local FACTION_CONSTANTS = {
	['Horde'] = {
    icon = "MountJournalIcons-Horde",
    color = '|cffff2216'
  },
	['Alliance'] = {
    icon = "MountJournalIcons-Alliance",
    color = '|cff64a0d3'
  }
};

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
  
  interfaceShowClassIconsInList = true,
  interfaceShowFactionIconInList = true,
  interfaceUseClassColorsWhereUseful = true,
  
  interfaceShowDetailsDebugText = true
};

function AllTheSetsGetOptions()
  return options
end

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

function MyDataProvider:CacheSets()
  if (not self.sets) then
    self.sets = { }
 
    C_TransmogCollection.ClearSearch(2)
    local allSets = C_TransmogSets.GetAllSets();
    local count = 0
    
    -- first we cache all sets
    for i, set in ipairs(allSets) do
      self.sets[set.setID] = set
      count = count + 1
    
      -- we set singleClass as the class for the set if available
      set.singleClass = classConstants[set.classMask]      
      -- otherwise we set armorClass as the the entry for the set if available
      set.armorClass = armorClassConstants[set.classMask]
      
      if set.classMask ~= 0 and not set.singleClass and not set.armorClass then
        debug(true, 'Set ' .. set.setID .. ' ' .. set.name .. ' has a wrong class specificaton (' .. set.classMask .. ')')
      end
    end
    
    debug(true, 'cached ' .. count .. ' sets')
  
    -- now we create a map of all variants for the sets with the following structure
    -- variant[baseSetID] = { baseSet, variantSet1, variantSet2, ...}
    self.variantSets = { }
  
    for i, set in pairs(self.sets) do     
      if set.baseSetID then
        if not self.variantSets[set.baseSetID] then
          assert(self.sets[set.baseSetID], 'must be non-nil')
          self.variantSets[set.baseSetID] = { self.sets[set.baseSetID] }
        end
        self.variantSets[set.baseSetID][#self.variantSets[set.baseSetID] + 1] = set      
      end
    end
  
    -- sort variants by uiOrder
    for _, variants in pairs(self.variantSets) do
      table.sort(variants, function(s1, s2)
        return s1.uiOrder < s2.uiOrder
      end)
    end
          
    self:DetermineFavorites();
  
    -- compute a map of sets by place (label field) to find sets for different classes for same place
    self.setsByPlace = { }  
    for i, set in pairs(self.sets) do
      if set.label and not set.baseSetID then
        if not self.setsByPlace[set.label] then
          self.setsByPlace[set.label] = { }
        end
    
        self.setsByPlace[set.label][#self.setsByPlace[set.label] + 1] = set
      end
    end
  end

  return self.sets
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

function MyDataProvider:GetFilteredSets()
  if (not self.filteredSets) then    
    self.filteredSets = { }
    
    local searchText = WardrobeCollectionFrame.searchBox:GetText()
    local sets = self:GetSets();
    
    for i, set in pairs(sets) do
      -- if set is a base set and filter is matching
      if not set.baseSetID and self:IsMatching(searchText, set) then               
        self.filteredSets[#self.filteredSets + 1] = set
      end
    end
    
    self:SortSets(self.filteredSets);
    
    debug(true, 'caching filtered sets: ' .. #self.filteredSets) 
  end
    
  return self.filteredSets
end


function MyDataProvider:GetBaseSetByID(setID)
  local sets = self:GetSets();
  return sets[setID].baseSetID and sets[baseSetID] or sets[setID]
end

function MyDataProvider:GetSetsByPlace(label)
  if not self.setsByPlace then
    self:CacheSets()
  end
  return self.setsByPlace[label] or { }
end

function MyDataProvider:GetVariantSets(baseSetID)
  if (not self.variantSets) then
    self:CacheSets()
  end
  return self.variantSets[baseSetID] or { };
end

function MyDataProvider:GetSets()
  if (not self.sets) then 
    self:CacheSets() 
  end
  return self.sets;
end

function MyDataProvider:GetSetInfo(setID)
  local sets = self:GetSets()
  return sets[setID]
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
  
  self.sets = nil;
  self.filteredSets = nil;
  self.baseSetsData = nil;
  self.variantSets = nil;
  self.usableSets = nil;
  self.sourceData = nil;
  self.setsByPlace = nil;
  
  
  self.collectedData = nil;
end

function MyDataProvider:ClearFilteredSets()
  self.filteredSets = nil;
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
  local baseSets = self:GetSets();
  for id, set in pairs(baseSets) do
    set.favoriteSetID = nil;
    if (set.favorite) then
      set.favoriteSetID = set.setID;
    else
      local variantSets = self:GetVariantSets(id);
      if (type(variantSets) == "table") then
        for j = 1, #variantSets do
          if ( variantSets[j].favorite ) then
            set.favoriteSetID = variantSets[j].setID;
            break;
          end
        end
      end
    end
  end
end

local SetsDataProvider = CreateFromMixins(MyDataProvider);

local function ClassMaskToString(bitmask, colorized)
  local classNames = UnitSex('player') == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE

  local result = ''
  for i, class in pairs(classConstants) do
    if BitWiseOperation(bitmask, i, AND) ~= 0 then
      local name = classNames[class.name]
      
      if colorized then
        result = result .. (result == '' and '' or "|cffffffff, ") .. '|c' .. RAID_CLASS_COLORS[class.name].colorStr .. name;
      else
        result = result .. (result == '' and "" or ", ") .. name;
      end
    end
  end
  return result
end

local function MyWardrobeSetsCollectionMixin_SelectSet(self, setID)
  debug(true, 'selecting set ' .. setID)
  
  self.selectedSetID = setID;

  local baseSetID = C_TransmogSets.GetBaseSetID(setID);
  local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
  if ( #variantSets > 0 ) then
    self.selectedVariantSets[baseSetID] = setID;
  end

  self:Refresh();
end

local function MyWardrobeSetsCollectionMixin_GetDefaultSetIDForBaseSet(self, baseSetID)
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


local function MyWardrobeSetsCollectionMixin_OnSearchUpdate(self)
  if ( self.init ) then
    SetsDataProvider:ClearFilteredSets();
    self:Refresh();
  end
end

local DETAILS_TITLE_COLOR = CreateColor(1, 0.82, 0)

local function MyWardrobeSetsCollectionMixin_DisplaySet(self, setID)
  local setInfo = SetsDataProvider:GetSetInfo(setID)
  
  if not setInfo then
    self.DetailsFrame:Hide();
    self.Model:Hide();
    return;
  else
    self.DetailsFrame:Show();
    self.Model:Show();
  end

  self.DetailsFrame.Name:SetText(setInfo.name);
    
  if options.interfaceUseClassColorsWhereUseful and setInfo.singleClass then
    local color = RAID_CLASS_COLORS[setInfo.singleClass.name]
    self.DetailsFrame.Name:SetTextColor(color.r, color.g, color.b)
  else
    self.DetailsFrame.Name:SetTextColor(DETAILS_TITLE_COLOR.r, DETAILS_TITLE_COLOR.g, DETAILS_TITLE_COLOR.b)
  end
    
  if self.DetailsFrame.Name:IsTruncated() then
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
    
    if sortedSources[i].collected then
      itemFrame.Icon:SetDesaturated(false);
      itemFrame.Icon:SetAlpha(1);
      itemFrame.IconBorder:SetDesaturation(0);
      itemFrame.IconBorder:SetAlpha(1);

      local transmogSlot = C_Transmog.GetSlotForInventoryType(itemFrame.invType);
      if C_TransmogSets.SetHasNewSourcesForSlot(setID, transmogSlot) then
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
  if self.DetailsFrame.ClassChoiceButton and setInfo.label then
    local setsForPlace = SetsDataProvider:GetSetsByPlace(setInfo.label)
    if (setsForPlace and #setsForPlace > 1) then
      self.DetailsFrame.ClassChoiceButton:Show()
      
      assert(setInfo.singleClass or setInfo.armorClass, "grouped set entry doesn't have a class or an armor class specified")
      
      if (setInfo.singleClass) then
        local classNames = UnitSex('player') == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
        local color = RAID_CLASS_COLORS[setInfo.singleClass.name]
      
        self.DetailsFrame.ClassChoiceButton:GetFontString():SetText('|c' .. color.colorStr .. classNames[setInfo.singleClass.name])
        -- self.DetailsFrame.ClassChoiceButton:GetFontString():SetTextColor(color.r, color.g, color.b, 1.0)
      else
        self.DetailsFrame.ClassChoiceButton:GetFontString():SetText(COLORS.white .. setInfo.armorClass.name)
        -- self.DetailsFrame.ClassChoiceButton:GetFontString():SetTextColor(1.0, 1.0, 1.0, 1.0)
      end
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
    
    string = string .. '\n|cffffffffclassMask: ' .. setInfo.classMask .. '\n'
    string = string .. '|cffffffffclasses: ' .. ClassMaskToString(setInfo.classMask, true) .. '\n'
    
    local setsForPlace = SetsDataProvider:GetSetsByPlace(setInfo.label)
    if (setsForPlace and #setsForPlace > 1) then
      string = string .. '|cffffffffgroup: ' .. setInfo.label .. ' (' .. #setsForPlace .. ')\n'
    else
      string = string .. '|cffffffffgroup: none\n'
    end
    
    if (setInfo.requiredFaction) then
      string = string .. '|cfffffffffaction: ' .. FACTION_CONSTANTS[setInfo.requiredFaction].color .. setInfo.requiredFaction.. '\n'
    end
    
    self.DetailsFrame.DebugString:SetText(string)
    self.DetailsFrame.DebugString:Show()
  else
    self.DetailsFrame.DebugString:Hide()
  end
end

local function MyWardrobeSetsCollectionMixin_OpenVariantSetsDropDown()
  local selectedSetID = WardrobeCollectionFrame.SetsCollectionFrame:GetSelectedSetID();
  if ( not selectedSetID ) then
    return;
  end
  local info = UIDropDownMenu_CreateInfo();
  local baseSetID = C_TransmogSets.GetBaseSetID(selectedSetID);
  local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
  for _, variantSet in pairs(variantSets) do
    local numSourcesCollected, numSourcesTotal = SetsDataProvider:GetSetSourceCounts(variantSet.setID);
    local colorCode = IN_PROGRESS_FONT_COLOR_CODE;
    if ( numSourcesCollected == numSourcesTotal ) then
      colorCode = NORMAL_FONT_COLOR_CODE;
    elseif ( numSourcesCollected == 0 ) then
      colorCode = GRAY_FONT_COLOR_CODE;
    end
    info.text = format(ITEM_SET_NAME, variantSet.description..colorCode, numSourcesCollected, numSourcesTotal);
    info.checked = function() return variantSet.setID == selectedSetID end;
    info.func = function() WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(variantSet.setID); end;
    UIDropDownMenu_AddButton(info);
  end
end

local function ScrollFrameRedrawList(self)
  -- local self = WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame
  
  local offset = HybridScrollFrame_GetOffset(self);
  local buttons = self.buttons;
  local baseSets = SetsDataProvider:GetFilteredSets();

  -- show the base set as selected
  local selectedSetID = self:GetParent():GetSelectedSetID();
  local selectedBaseSetID = selectedSetID and C_TransmogSets.GetBaseSetID(selectedSetID);

  for i = 1, #buttons do
    local color;
    local button = buttons[i];
    local setIndex = i + offset;
    if ( setIndex <= #baseSets ) then
      local baseSet = baseSets[setIndex];
      button:Show();
      button.Name:SetText(baseSet.name);
      local topSourcesCollected, topSourcesTotal = SetsDataProvider:GetSetSourceTopCounts(baseSet.setID);
      local setCollected = topSourcesCollected == topSourcesTotal
      
      if options.interfaceUseClassColorsWhereUseful then
        --if (topSourcesCollected > 0) then
        if (baseSet.singleClass) then
          color = RAID_CLASS_COLORS[baseSet.singleClass.name]
        else
          color = IN_PROGRESS_FONT_COLOR
        end

        if topSourcesCollected == 0 then
          color.a = 0.3
        elseif not setCollected then
          color.a = 0.7 -- + 0.2 * (topSourcesCollected / topSourcesTotal)
        else
          color.a = 1.0
        end
      else      
        if (setCollected) then
          color = NORMAL_FONT_COLOR
        elseif (topSourcesCollected == 0) then
          color = GRAY_FONT_COLOR
        else
          color = IN_PROGRESS_FONT_COLOR       
        end
      end
   
      if options.interfaceShowClassIconsInList then
        local setClass = baseSet.singleClass
      
        if setClass then
          local texCoords = CLASS_ICON_TCOORDS[setClass.name]      
        
          button.ClassIcon:SetTexCoord(unpack(texCoords))
          button.ClassIcon:Show()
        else
          button.ClassIcon:Hide()
        end
      end
      
      if options.interfaceShowFactionIconInList then
        local iconName = FACTION_CONSTANTS[baseSet.requiredFaction] and FACTION_CONSTANTS[baseSet.requiredFaction].icon
        
        if iconName then
  				button.FactionIcon:SetAtlas(iconName, true);
          button.FactionIcon:Show();
        else
          button.FactionIcon:Hide();
        end
      end
      
      
      button.Name:SetTextColor(color.r, color.g, color.b, color.a);
      button.Label:SetText(baseSet.label);
      button.Icon:SetTexture(SetsDataProvider:GetIconForSet(baseSet.setID));
      button.Icon:SetDesaturation((topSourcesCollected == 0) and 1 or 0);
      button.SelectedTexture:SetShown(baseSet.setID == selectedBaseSetID);
      button.Favorite:SetShown(baseSet.favoriteSetID);
      button.New:SetShown(SetsDataProvider:IsBaseSetNew(baseSet.setID));
      button.setID = baseSet.setID;

      if (topSourcesCollected == 0 or setCollected) then
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

function InitizalizeRightClickMenu(self)
	if (not self.baseSetID) then
		return;
	end
  
  debug(true, "opening favorite menu")

	local baseSet = SetsDataProvider:GetBaseSetByID(self.baseSetID);
	local variantSets = SetsDataProvider:GetVariantSets(self.baseSetID);
	local useDescription = (#variantSets > 0);

	local info = UIDropDownMenu_CreateInfo();
	info.notCheckable = true;
	info.disabled = nil;

	if (baseSet.favoriteSetID) then
		if (useDescription) then
			local setInfo = SetsDataProvider:GetSetInfo(baseSet.favoriteSetID);
			info.text = format(TRANSMOG_SETS_UNFAVORITE_WITH_DESCRIPTION, setInfo.description);
		else
			info.text = BATTLE_PET_UNFAVORITE;
		end
		info.func = function()
			C_TransmogSets.SetIsFavorite(baseSet.favoriteSetID, false);
      
      for _, variant in pairs(variantSets) do
        variant.favoriteSetID = nil
      end
   
      ScrollFrameRedrawList(WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame)
		end
	else
		local targetSetID = WardrobeCollectionFrame.SetsCollectionFrame:GetDefaultSetIDForBaseSet(self.baseSetID);
		if (useDescription) then
			local setInfo = C_TransmogSets.GetSetInfo(targetSetID);
			info.text = format(TRANSMOG_SETS_FAVORITE_WITH_DESCRIPTION, setInfo.description);
		else
			info.text = BATTLE_PET_FAVORITE;
		end
		info.func = function()
			C_TransmogSets.SetIsFavorite(targetSetID, true);
      
      for _, variant in pairs(variantSets) do
        variant.favoriteSetID = targetSetID
      end
 
      ScrollFrameRedrawList(WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame)
		end
	end

	UIDropDownMenu_AddButton(info, level);
	info.disabled = nil;

	info.text = CANCEL;
	info.func = nil;
	UIDropDownMenu_AddButton(info, level);
end




local function MyFilterDropDown_Inizialize(self, level)
  -- like original function but we call MyFilterDropDown_InitializeBaseSets for sets drop down
  
  debug(true, "initialize dropdown ", level)
  if ( not WardrobeCollectionFrame.activeFrame ) then
    return;
  end

  if (WardrobeCollectionFrame.activeFrame.searchType == LE_TRANSMOG_SEARCH_TYPE_ITEMS ) then
    WardrobeFilterDropDown_InitializeItems(self, level);
  elseif (WardrobeCollectionFrame.activeFrame.searchType == LE_TRANSMOG_SEARCH_TYPE_BASE_SETS ) then
    MyFilterDropDown_InitializeBaseSets(self, level);
  end
end

local function UI_DecorateDropDownItemForClass(info, class, faction)
  local classNames = UnitSex('player') == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
  local texCoords = CLASS_ICON_TCOORDS[class]      
  
  info.text = '|c' .. RAID_CLASS_COLORS[class].colorStr .. classNames[class]
  info.icon = 'Interface\\TargetingFrame\\UI-Classes-Circles'
  info.tCoordLeft = texCoords[1]
  info.tCoordRight = texCoords[2]
  info.tCoordTop = texCoords[3]
  info.tCoordBottom = texCoords[4]
  
  if faction then
    info.text = info.text .. COLORS.white .. ' (' .. FACTION_CONSTANTS[faction].color .. faction .. COLORS.white .. ')'
  end
end

local function Refresh()
  SetsDataProvider:ClearFilteredSets()
  WardrobeCollectionFrame.SetsCollectionFrame:Refresh()
end

function MyFilterDropDown_InitializeBaseSets(self, level)

  local info = UIDropDownMenu_CreateInfo();
  info.keepShownOnClick = true
  
  if level == 1 then  
    info.keepShownOnClick = true;
    info.isNotRadio = true;
    info.text = COLLECTED;
    info.func = function(_, _, _, value) 
      options.filterShowCollected = value
      Refresh()
    end
    info.checked = options.filterShowCollected
    UIDropDownMenu_AddButton(info, level);

    info.text = NOT_COLLECTED;
    info.func = function(_, _, _, value) 
      options.filterShowNotCollected = value 
      Refresh()
    end
    info.checked = options.filterShowNotCollected
    UIDropDownMenu_AddButton(info, level);
    
    info.text = 'PvE';
    info.func = function(_, _, _, value) 
      options.filterShowPvE = value 
      Refresh()
    end
    info.checked = options.filterShowPvE
    UIDropDownMenu_AddButton(info, level);
    
    info.text = 'PvP';
    info.func = function(_, _, _, value) 
      options.filterShowPvP = value 
      Refresh()
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
      Refresh()
    end
    info.checked = options.filterShowHiddenByDefault
    UIDropDownMenu_AddButton(info, level);
    
    -- Reset filter button
    info.notCheckable = true
    info.text = 'Reset default filter' -- TODO: localize
    info.func = function(_, _, _, value) 
      ResetSearchFilter();
      UIDropDownMenu_Refresh(self, 1, 1);
      Refresh()
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
          Refresh()
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
        Refresh()
        UIDropDownMenu_Refresh(self, 1, 2);
      
      end
      UIDropDownMenu_AddButton(info, level)  
    
    
      info.text = UNCHECK_ALL
      info.func = function() 
        options.filterClassMask = NO_CLASSES_MASK
        Refresh()
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
          Refresh()
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
        Refresh()
        UIDropDownMenu_Refresh(self, 1, 2);
      
      end
      UIDropDownMenu_AddButton(info, level)  
    
    
      info.text = UNCHECK_ALL
      info.func = function() 
        options.filterExpansionMask = NO_EXPANSIONS_MASK
        Refresh()
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
        Refresh()
      end
      UIDropDownMenu_AddButton(info, level)  
    
      info.text = 'Horde' -- TODO:localize
      info.icon = 'Interface\\Timer\\Horde-Logo'
      info.checked = function() return options.filterFactionMask.Horde end
      info.func = function(_, _, _, value) 
        options.filterFactionMask.Horde = value 
        Refresh()
      end
      UIDropDownMenu_AddButton(info, level)  
         
    end
  end
end

local function EnhanceBlizzardUI()
  local DetailsFrame = WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame
  
  -- Add new elements to the set choice button template
  
  local buttons = WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame.buttons       
  
  for i = 1, #buttons do
    local button = buttons[i];
    
    -- Class icon
    button.ClassIcon = button:CreateTexture(nil, "BACKGROUND")
    button.ClassIcon:SetAlpha(0.5)
    button.ClassIcon:SetPoint("TOPRIGHT", -1, -2);
    button.ClassIcon:SetTexture('Interface\\TargetingFrame\\UI-Classes-Circles')
    button.ClassIcon:SetSize(20, 20)
    button.ClassIcon:Hide()
    
    -- Faction icon
    button.FactionIcon = button:CreateTexture(nil, "BORDER")
    button.FactionIcon:SetPoint('BOTTOMRIGHT', -1, 1)
    button.FactionIcon:SetSize(90, 44)
    button.FactionIcon:Hide()
  end
 
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
      local setInfo = SetsDataProvider:GetSetInfo(setID)
      local setsForPlace = SetsDataProvider:GetSetsByPlace(setInfo.label)
      
      for _, otherSet in pairs(setsForPlace) do
        if otherSet.singleClass then
          UI_DecorateDropDownItemForClass(info, otherSet.singleClass.name, otherSet.requiredFaction)
        elseif otherSet.armorClass then
          info.text = otherSet.armorClass.name
          info.icon = nil
          info.colorCode = FACTION_CONSTANTS[otherSet.requiredFaction] and FACTION_CONSTANTS[otherSet.requiredFaction].color
        end

        info.checked = function() return setInfo.setID == otherSet.setID end
        info.func = function() 
          WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(otherSet.setID)
        end
        UIDropDownMenu_AddButton(info, level)        
      end
    end
        
    UIDropDownMenu_Initialize(DetailsFrame.ClassChoiceDropDown, initialization, "MENU")
  end
  
  -- Favorite right click menu
  assert(WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame.FavoriteDropDown and InitizalizeRightClickMenu, "must be non-nil")
	UIDropDownMenu_Initialize(WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame.FavoriteDropDown, InitizalizeRightClickMenu, "MENU");
  
  -- Debug String  
  DetailsFrame.DebugString = DetailsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  DetailsFrame.DebugString:SetJustifyH("LEFT")
  DetailsFrame.DebugString:SetSize(300,200)
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
  elseif event == 'PLAYER_LOGOUT' then
    
    if not AllTheSetsOptions then
      AllTheSetsOptions = {}
    end
    
    AllTheSetsOptions.options = options
  elseif (event == "ADDON_LOADED" and select(1, ...) == "AllTheSets") then
    
    if AllTheSetOptions and AllTheSetsOptions.options then
      options = AllTheSetsOptions.options
    end
    
  elseif (event == "ADDON_LOADED" and select(1, ...) == "Blizzard_Collections") then
    -- self:UnregisterEvent("ADDON_LOADED");
    print "Registering hooks for AllTheSets";

    -- WardrobeCollectionFrame.SetsTransmogFrame
    -- WardrobeCollectionFrame.FilterButton:SetEnabled(false);
    
    ResetSearchFilter()

        
    WardrobeCollectionFrame.SetsCollectionFrame:HookScript("OnShow", 
    function(self) 
      --[[
      Blizzard UI sets frame has a design flaw: the data provider for all the sets is an hidden local
      variable which cannot be replaced. This means that all methods of the WadrobeSetsCollectionMixin
      which use SetsDataProvider must be replaced with new method which uses our implementation
      ]]        

      WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame['update'] = ScrollFrameRedrawList
      WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame['Update'] = ScrollFrameRedrawList
        
      EnhanceBlizzardUI()
        
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
frame:SetScript('OnEvent', onEvent)
frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('PLAYER_LOGOUT')
frame:RegisterEvent('ADDON_LOADED')


--[[ local function Neutralizer(box)
box:SetParent(UIParent)
box.scrollbar:SetValue(0)
box:Hide()
end ]]--


