
DarkRP.createCategory{
    name = "Other",
    categorises = "ammo",
    startExpanded = true,
    color = Color(0, 107, 0, 255),
    canSee = fp{fn.Id, true},
    sortOrder = 255,
}

DarkRP.createEntity("TFA Ammo", {
    ent = "touch_pickup_752_ammo_ar2",
    model = "models/starwars/items/power_cell.mdl",
    price = 0,
    max = 4,
    cmd = "buyammo",
    allowTools = true,
})
