-- SPDX-License-Identifier: GPL-3.0-or-later
core.register_craftitem("era_materials:iron_dust", {description="Iron Dust", inventory_image="era_dust.png"})
core.register_craft({type="cooking",output=era.mcl.ingot,recipe="era_materials:iron_dust",cooktime=10})
