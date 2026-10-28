-- SPDX-License-Identifier: GPL-3.0-or-later
-- Short pack guidance; recipes and craft achievements use the existing upstream APIs.
local pages={
 {title="Getting started",text="Gather materials at the natural spawn. Make wooden tools, a crafting table, stone tools and an ordinary furnace. The inventory recipe guide shows crafting patterns.\n\n"..
  "Collect iron, copper, coal, flint from gravel, and clay for bricks. Elepower adds other ores used later, including lead, tin, silver and zinc. Keep a source of wheat seeds and leaves.\n\n"..
  "The workshop is an optional supplied example. /workshop visits it; /explore returns to your saved natural spawn. Taking its supplies is optional.\n\n"..
  "Craft the first machines to unlock factory advancements. Use /awards to view your milestones.\n\n"..
  "/goals lists ten starter goals with small rewards; the current one shows at the right of the screen. "..
  "The top of the screen names the block you look at, its mod, stored power and how full a container is; /lookinfo hides it.\n\n"..
  "E opens and closes your inventory; E or Esc closes any other screen. Hold Left Ctrl while walking to sprint. K toggles flight and J fast movement. /manual reopens this manual."},
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
 {title="Farming",text="After powered soldering and diamond mining, build an Automatic Planter and Automatic Harvester. Use the inventory recipe guide and Elepower Tome for their components and recipes.\n\n"..
  "Bury the planter below the soil layer with water directly above it. Drag a wheat seed into the upper center layout slot: it selects a 3x3 patch with eight soil blocks around that water. The layout is a preview; put real seeds in the lower supply inventory.\n\n"..
  "Power both machines through conduits and face the harvester toward the field at crop height. Configure one filter for wheat seeds and another for wheat. Return seeds to the planter; send wheat to a drawer or barrel. Place a Mesecons blinking control beside each filter after configuration.\n\n"..
  "New workshop supplies include seeds, a wheat item and two controls. The harvester drops overflow above itself; collect loose items before they expire. Sludge is a byproduct: drain its buffer periodically so it has room to keep harvesting."},
 {title="Trees",text="Try one oak at a time with the same powered planter and harvester. Put the planter two blocks below the sapling space, with one dirt block between them. Keep the surrounding planting area stone. Select an oak sapling in the upper center layout slot and put real spare saplings in the lower supply slots.\n\n"..
  "Place the harvester four blocks from the sapling, at sapling height and facing it. A glass block eight blocks directly above the sapling space limits the tested layout to a small oak; leave room around it for the canopy. Unrestricted large oaks can leave branches beyond the cutter's reach.\n\n"..
  "Route the cutter's output into a barrel. Place an Adjustable Vacuum Tube two blocks beside the sapling at ground level, set its radius to 8 and connect it to that output line. A sapling-only filter with a blinking control can return saplings from the barrel to the planter's real supply.\n\n"..
  "Start with one cycle: after planting, use the planter's state button to select Always off. Let the cutter work and the remaining leaves decay, then enable planting again. Sapling drops are random; keep a reserve. The cutter produces logs and ordinary leaf drops, not leaf blocks. Use shears separately to gather leaves for plastic."},
 {title="Smeltery",text="Craft grout from sand, gravel and clay, and bake it in a furnace into seared bricks. Four seared bricks make a Seared Bricks block; eight around an empty centre make a Smeltery Controller.\n\n"..
  "Build a floor of Seared Bricks, up to 7x7. Wall in the space above it with Seared Bricks, leaving the inside empty; the corners may be left out. Put the controller in the wall, facing out. Each extra wall layer adds space.\n\n"..
  "Right-click the controller. Put a lava bucket in the Lava slot and ores, ingots, nuggets or metal blocks in the melting slots. Raw ore and ore blocks melt into twice the metal. The screen shows the molten metal; 144 mB is one ingot.\n\n"..
  "Breaking the controller loses its molten metal. The Casting page explains getting it back out."},
 {title="Casting",text="Replace one wall block of your smeltery with a Seared Drain (six seared bricks in two columns). Place a Faucet (three seared bricks in a V) on the drain's outside, and a Casting Table or Casting Basin directly under the faucet.\n\n"..
  "A Casting Table (seven seared bricks, like a table) needs an Ingot Cast: two seared bricks and an iron ingot, which you keep. It casts one ingot from 144 mB. A Casting Basin (seven seared bricks, like a bowl) casts a metal block from 1296 mB.\n\n"..
  "Right-click the faucet to pour. It pours the metal marked > on the controller screen; the buttons there change it. Take the finished ingot or block out of the table or basin before pouring again."},
 {title="Storage",text="Logistica builds an item network that delivers items only when something asks for them. Start with its Lava Furnace: clay, obsidian, iron ingots and two empty buckets. Fill it with lava. It turns sand plus ice or snow into Silverin, and Silverin plus iron into Silverin plates.\n\n"..
  "Plates, Silverin circuits and optic cable make a Network Controller and an Access Point. Connect storage and machines to the controller with optic cable. The Access Point searches everything on the network, and its Recursive Crafting Upgrade crafts missing ingredients for you.\n\n"..
  "Craft the Logistica Guide Book (sand, paper, sand in a column) for every machine and upgrade. Drawers and barrels still work; use whichever suits your base.\n\n"..
  "Bigger chests: surround a chest with eight copper ingots for a Copper Chest (45 slots), a Copper Chest with eight iron ingots for an Iron Chest (54), an Iron Chest with eight gold ingots for a Gold Chest (81). "..
  "A Diamond Chest (108) is a Gold Chest between two diamonds, with glass rows above and below. Breaking a chest drops its contents. Pipeworks tubes and filter-injectors connect on every side but the front."},
 {title="Travel",text="Travelnet boxes teleport you between stations. Craft one with glass down both sides and iron ingot, block of redstone, iron ingot down the middle.\n\n"..
  "Place it, right-click, then name the station and a network. All of your stations with the same network name connect. Punch a box to refresh its station list, then right-click it to travel.\n\n"..
  "The Elevator (iron ingots and glass) links boxes stacked above each other on different floors.\n\n"..
  "The Jetpack (steel ingots, a capacitor, a battery and two wound copper coils) works anywhere in your inventory. Hold jump to fly up; hold sneak while falling to glide down. "..
  "It uses charge as you fly: put it in a power cell's charge slot to refill it."},
 {title="Exploring",text="Newly generated terrain can contain extra structures: desert oases, brick pyramids, birch forest temple ruins, graveyards, loggers' camps, sandstone obelisks and ice towers. Some hold loot.\n\n"..
  "Areas you have already visited do not change, so travel into new land to find them.\n\n"..
  "Rare wooden book towers stand in grassland. Their Wise Bookshelves matter for magic; see the Magic page."},
 {title="Magic",text="Magic starts underground. Elemental crystals grow on cave floors and ceilings above the deepslate, in six elements: air, earth, fire, water, light and dark.\n\n"..
  "Craft a Steel-Capped Wand from a steel cap (iron ingots), a wand core (two sticks) and any crystal. Right-click crystals with the wand to tap their elements. Use the wand on a bookshelf to get the Magicalities guide book.\n\n"..
  "Craft a Table from eight logs; it is your Research Table. Use the wand on a second, empty Table to make an Arcane Table for magical crafting. Research unlocks most recipes: right-click Wise Bookshelves in book towers for research notes, then research at the table with the guide book, ink and quill, and paper.\n\n"..
  "The Cauldron (iron blocks) needs fire beneath it and water inside. It makes Tellium for magical tools and Transterra for reshaping the world. The guide book explains each step."}
}
era_playtest.factory_guide_pages=pages

function era_playtest.show_factory_guide(name,page)
 page=tonumber(page) or 1
 if page~=math.floor(page) or not pages[page] then page=1 end
 local selected=pages[page]
 local tabs={}
 for _,entry in ipairs(pages) do tabs[#tabs+1]=core.formspec_escape(entry.title) end
 core.show_formspec(name,"era_playtest:factory_guide",
  "formspec_version[4]size[14,10]label[0.5,0.45;Golden Era Manual]"..
  "tabheader[0.5,1.65;factory_page;"..table.concat(tabs,",")..";"..page..";false;false]"..
  "textarea[0.5,2.1;13,6.1;;;"..core.formspec_escape(selected.text).."]"..
  "button[0.5,8.8;3,0.7;workshop_help;Workshop help]"..
  "button[3.8,8.8;3,0.7;advancements;Advancements]"..
  "button[7.1,8.8;3,0.7;goals;Starter goals]"..
  "button_exit[10.5,8.8;3,0.7;close;Continue]")
end

core.register_chatcommand("factoryguide",{description="Read the early survival and factory progression guide",func=function(name)
 era_playtest.show_factory_guide(name,1);return true
end})
core.register_chatcommand("manual",{description="Open the Golden Era Manual",func=function(name)
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
 elseif fields.advancements then awards.show_to(name,name,nil,false)
 elseif fields.goals then era_playtest.show_goals(name) end
 return true
end)

local milestones={
 {id="hand_power",item="elepower_machines:grindstone",title="Factory: by hand",description="Craft an Elepower Grindstone. Add a Hand Crank above it to grind without electricity."},
 {id="early_alloys",item="elepower_machines:coal_alloy_furnace",title="Factory: first alloys",description="Craft a Coal-fired Alloy Furnace for alloys before electrical power."},
 {id="generation",item="elepower_machines:generator",title="Factory: first generator",description="Craft a Coal-fired Generator. Connect conduits to power your first processor."},
 {id="processing",item="elepower_machines:pulverizer",title="Factory: ore processing",description="Craft a Pulverizer to grind raw iron into two dust."},
 {id="routing",item="pipeworks:mese_filter",title="Factory: item routing",description="Craft a filter-injector. Add tubes and a Mesecons control to move items automatically."},
 {id="storage",item="drawers:oakwood1",title="Factory: bulk storage",description="Craft an oak drawer for bulk materials. Right-click its front to store items."},
 {id="farming",item="elepower_farming:harvester",title="Factory: renewable harvest",description="Craft an Automatic Harvester. Add a powered planter and filter seeds back to its supply inventory."},
}
era_playtest.factory_milestones=milestones
for _,goal in ipairs(milestones) do
 awards.register_achievement("era_playtest:"..goal.id,{
  title=goal.title,description=goal.description,icon="mcl_achievements_button.png",
  type="Advancement",group="Golden Era",
  trigger={type="craft",item=goal.item,target=1},
 })
end
