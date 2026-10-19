-- Peat, Isaac-Style — Пит (Fiend Folio) в забеге в стиле Айзека вместо нарезки из мультфильма (автор blackhellvelz):
-- свой лист тела и головы в раскладке Айзека, костюмы предметов ложатся как у Айзека, на коне — всадником.
-- Мод Мастерской собирается tools/build_workshop.py.
LOCALFIXES = LOCALFIXES or {}
if LOCALFIXES.AllInOne then
	Isaac.DebugString("[Peat Isaac-Style] пропуск: стоит общая сборка localfixes")
	return
end
local mod = RegisterMod("Peat, Isaac-Style", 1)
LOCALFIXES.Mod = mod
local ok, r = pcall(include, "peat_skin")
if not ok then Isaac.DebugString("[Peat Isaac-Style] peat_skin: " .. tostring(r)) end
