-- SPDX-License-Identifier: GPL-3.0-or-later
-- Short pack guidance; recipes and craft achievements use the existing upstream APIs.
local pages={
 {title="Getting started",text="Gather materials at the natural spawn. Make wooden tools, a crafting table, stone tools and an ordinary furnace. The inventory recipe guide shows crafting patterns.\n\n"..
  "Collect iron, copper, coal, flint from gravel, and clay for bricks. Elepower adds other ores used later, including lead, tin, silver and zinc. Keep a source of wheat seeds and leaves.\n\n"..
  "The workshop is an optional supplied example. /workshop visits it; /explore returns to your saved natural spawn. Taking its supplies is optional.\n\n"..
  "Craft the first machines to unlock factory advancements. Use /awards to view your milestones."},
 {title="Metals and alloys",text="Smelt raw iron into iron ingots, then smelt those ingots a second time to make Elepower low carbon steel. This uses an ordinary furnace.\n\n"..
  "Craft an Elepower Grindstone and Hand Crank before powered machines. Place the crank directly above the grindstone. Put a grindable ingredient in the grindstone and right-click the crank to turn it.\n\n"..
  "Craft the Coal-fired Alloy Furnace to make early alloys without electrical power. Its crafting recipe uses brick blocks, two ordinary furnaces and coal. Brass uses copper and silver in this pack.\n\n"..
  "Use the recipe guide for exact counts and your Elepower Tome for machine recipes. The stock mod provides the Tome at first join; a spare copy is in the workshop supplies."},
 {title="Electronics",text="Early machines need components as well as metals. Follow their ingredients in the recipe guide instead of trying to craft the largest machine first.\n\n"..
  "Leaves can be crafted into oil extract. Ordinary furnace processing turns oil extract into paraffin, then into plastic sheets. Shears help collect leaves.\n\n"..
  "Circuit boards use an etching process: acidic compound, water and a blank PCB. Read the Elepower Tome before making the etching setup. Copper dust and wheat seeds are part of this path.\n\n"..
  "Craft chips, capacitors and integrated circuits as their recipes require. The powered Solderer and higher circuits come later; a power cell is not required to run your first generator and processor."},
 {title="First power",text="Build a Coal-fired Generator, conduits and a Pulverizer. Connect conduits to the machines and add coal to the generator. Use the existing recipe guide for lead, wire, coils and machine blocks.\n\n"..
  "The generator can power a processor directly through conduits. Power cells are a later storage upgrade. A single stock generator supplies power slowly, so give machines time to work.\n\n"..
  "The Pulverizer turns raw iron into two iron dust. Smelt the dust into iron ingots. An ordinary furnace can smelt dust while you work toward an electrically powered furnace.\n\n"..
  "Right-click a machine to inspect its input, output, fuel and energy. Empty its item slots, including tools and cards, before mining it. Drain fluid buffers before moving fluid machines. The supplied workshop demonstrates the powered line and takes about two minutes for its first two raw iron."},
 {title="Automation",text="Begin with one processing step and a nearby storage container. Pipeworks tubes and filter-injectors can move items between compatible machines.\n\n"..
  "The workshop uses Mesecons blinking controls to pulse filter-injectors. Follow the tube direction and watch which inventory each filter extracts from. Filter-injectors resist piston movement; mine, place and reconfigure them to move your setup. Build a short route before expanding it.\n\n"..
  "Storage Drawers hold bulk materials. Right-click the front to store items; left-click to retrieve a stack, or sneak to retrieve one item. E + left-click toggles the item-type lock. Connect drawers or trim to a controller for bulk deposits, including Pipeworks input; retrieve from drawer fronts. The recipe guide includes upgrades and controllers.\n\n"..
  "Pipeworks autocrafters need output room for both products and returned containers. Crafting conduits from copper wire returns empty spools. Filter the conduits into storage and collect or route the spools separately; a full output pauses crafting.\n\n"..
  "Try fluid tanks and ducts, better generation, powered tools or mining machines next. Build one addition at a time and check that the previous line still works."},
}
era_playtest.factory_guide_pages=pages

function era_playtest.show_factory_guide(name,page)
 page=tonumber(page) or 1
 if page~=math.floor(page) or not pages[page] then page=1 end
 local selected=pages[page]
 local tabs={}
 for _,entry in ipairs(pages) do tabs[#tabs+1]=core.formspec_escape(entry.title) end
 core.show_formspec(name,"era_playtest:factory_guide",
  "formspec_version[4]size[14,10]label[0.5,0.45;Golden Era — Your first factory]"..
  "tabheader[0.5,1.65;factory_page;"..table.concat(tabs,",")..";"..page..";false;false]"..
  "textarea[0.5,2.1;13,6.1;;;"..core.formspec_escape(selected.text).."]"..
  "button[0.5,8.8;3,0.7;workshop_help;Workshop help]"..
  "button[4,8.8;3,0.7;advancements;Advancements]"..
  "button_exit[10.5,8.8;3,0.7;close;Continue]")
end

core.register_chatcommand("factoryguide",{description="Read the early survival and factory progression guide",func=function(name)
 era_playtest.show_factory_guide(name,1);return true
end})
core.register_on_player_receive_fields(function(player,formname,fields)
 local name=player:get_player_name()
 if formname=="era_playtest:help" and fields.factory_guide then
  era_playtest.show_factory_guide(name,1);return true
 end
 if formname~="era_playtest:factory_guide" then return false end
 if fields.quit then return true end
 if fields.factory_page then era_playtest.show_factory_guide(name,fields.factory_page)
 elseif fields.workshop_help then era_playtest.show_workshop_help(name)
 elseif fields.advancements then awards.show_to(name,name,nil,false) end
 return true
end)

local milestones={
 {id="hand_power",item="elepower_machines:grindstone",title="Factory: by hand",description="Craft an Elepower Grindstone. Add a Hand Crank above it to grind without electricity."},
 {id="early_alloys",item="elepower_machines:coal_alloy_furnace",title="Factory: first alloys",description="Craft a Coal-fired Alloy Furnace for alloys before electrical power."},
 {id="generation",item="elepower_machines:generator",title="Factory: first generator",description="Craft a Coal-fired Generator. Connect conduits to power your first processor."},
 {id="processing",item="elepower_machines:pulverizer",title="Factory: ore processing",description="Craft a Pulverizer to grind raw iron into two dust."},
 {id="routing",item="pipeworks:mese_filter",title="Factory: item routing",description="Craft a filter-injector. Add tubes and a Mesecons control to move items automatically."},
 {id="storage",item="drawers:oakwood1",title="Factory: bulk storage",description="Craft an oak drawer for bulk materials. Right-click its front to store items."},
}
era_playtest.factory_milestones=milestones
for _,goal in ipairs(milestones) do
 awards.register_achievement("era_playtest:"..goal.id,{
  title=goal.title,description=goal.description,icon="mcl_achievements_button.png",
  type="Advancement",group="Golden Era",
  trigger={type="craft",item=goal.item,target=1},
 })
end
