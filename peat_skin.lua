-- localfixes/peat_skin.lua — Пит (Fiend Folio) в забеге своим листом в стиле Айзека (19.10, слова пользователя: «И можешь
-- переделать спрайт Пита в игре самой / Он сейчас слишком всрато и шуточно выглядит»). Облик — по официальному портрету
-- Пита в FF (gfx/enemies/peat/portraitgiffin.png): лист gfx/characters/localfixes_peat.png рисует tools/peat_sprite.py
-- в раскладке Айзека (нос-картошка, открытый рот, подбородок из двух долей, уши, коричневые ботинки).
--
-- Как, не трогая FF: у Пита своя анимация gfx/characters/player_pete.anm2 (раскладка Айзека — те же слои, анимации и
-- нули, но лист — нарезка из мультфильма), и FF перезагружает её, если у игрока другой файл (ffscripts/dead/
-- fiend_b_skin_legitimate.lua), — поэтому файл игрока не меняется. Перед отрисовкой тела и головы (REPENTOGON
-- MC_PRE_RENDER_PLAYER_BODY / _HEAD) рисуется свой спрайт — анимация игрока игры (gfx/001.000_player.anm2) с нашим
-- листом, в той же анимации и кадре, что спрайт FF; слои FF скрыты (LayerState:SetVisible), а костюмы предметов игра
-- рисует как обычно — поверх тела и головы, в своём порядке. Нет FF или REPENTOGON — модуль ничего не делает.
local mod = LOCALFIXES.Mod
if not (mod and ModCallbacks.MC_PRE_RENDER_PLAYER_BODY and ModCallbacks.MC_PRE_RENDER_PLAYER_HEAD) then return end

local SHEET = "gfx/characters/localfixes_peat.png"
local GHOST = 13                                    -- слой призрака (ghost.png игры) — лист не меняется
local spr
local function sprite()
	if spr ~= nil then return spr end
	spr = Sprite()
	spr:Load("gfx/001.000_player.anm2", false)
	for l = 0, spr:GetLayerCount() - 1 do
		if l ~= GHOST then spr:ReplaceSpritesheet(l, SHEET) end
	end
	spr:LoadGraphics()
	if not spr:IsLoaded() then spr = false end
	return spr
end

local function isPeat(player)
	local t = FiendFolio and FiendFolio.PLAYER and FiendFolio.PLAYER.PEAT
	return t ~= nil and player:GetPlayerType() == t
end

-- слои FF — скрыть (рисуем свои); FF перезагрузил анимацию — скрыть снова
local function hideFF(fs, show)
	for l = 0, fs:GetLayerCount() - 1 do
		local L = fs:GetLayer(l)
		if L and L:IsVisible() ~= show then L:SetVisible(show) end
	end
end

-- WalkDown и WalkUp FF разворачивает по скорости — для своей нарезки (Питер сбоку); у раскладки Айзека их не разворачивают
local NOFLIP = { WalkDown = true, WalkUp = true }
local function pose(fs, s, anim, frame)
	local ok = pcall(s.SetFrame, s, anim, frame)
	if not ok then return false end
	s.Color = fs.Color
	s.Scale = fs.Scale
	s.Rotation = fs.Rotation
	s.Offset = fs.Offset                                -- на коне FF поднимает спрайт (Offset −27 / −5 / −50)
	s.FlipX = fs.FlipX and not NOFLIP[fs:GetAnimation()]
	s.FlipY = fs.FlipY
	return true
end

-- отражение в воде (проход RENDER_WATER_REFLECT) рисуется теми же вызовами: игра сама переворачивает картинку, поэтому
-- свой спрайт рисуется и там (19.10: без него на Ливне в воде отражались одни костюмы — вешалка, кровь — без тела)

-- ходьба (WalkDown/Up/Left/Right): игра рисует тело и голову по частям (RenderBody, RenderHead) — свой спрайт там же;
-- позы во весь рост (подбор с предметом над головой — PickupWalk*, радость, грусть, урон, смерть, люк…) игра рисует
-- целиком, без этих частей (19.10: Пит в них пропадал — слои FF скрыты, а части не вызывались) — свой спрайт перед
-- отрисовкой игрока
local function walking(anim) return anim:sub(1, 4) == "Walk" end

mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, offset)
	if not isPeat(player) then return end
	local fs = player:GetSprite()
	local anim = fs:GetAnimation()
	if walking(anim) then return end
	local s = sprite()
	if not s then return end
	if not pose(fs, s, anim, fs:GetFrame()) then
		hideFF(fs, true)
		return
	end
	hideFF(fs, false)
	s:Render(Isaac.WorldToRenderPosition(player.Position + player.PositionOffset) + (offset or Vector.Zero))
end)

-- тело: основная анимация ходьбы
mod:AddCallback(ModCallbacks.MC_PRE_RENDER_PLAYER_BODY, function(_, player, pos)
	if not isPeat(player) then return end
	local s = sprite()
	if not s then return end
	local fs = player:GetSprite()
	if not walking(fs:GetAnimation()) then return end
	if not pose(fs, s, fs:GetAnimation(), fs:GetFrame()) then
		hideFF(fs, true)                                -- анимации нет у игры — пусть рисует FF
		return
	end
	hideFF(fs, false)
	s:Render(pos)
end)

-- голова: наложенная анимация (HeadDown / HeadLeft / HeadRight / HeadUp) — только при ходьбе; в позах во весь рост
-- голова уже в кадре тела
mod:AddCallback(ModCallbacks.MC_PRE_RENDER_PLAYER_HEAD, function(_, player, pos)
	if not isPeat(player) then return end
	local s = sprite()
	if not s then return end
	local fs = player:GetSprite()
	local main = fs:GetAnimation()
	if not walking(main) then return end
	local ov = fs:GetOverlayAnimation()
	if not ov or ov == "" then return end
	if not pose(fs, s, ov, fs:GetOverlayFrame()) then return end
	s:Render(pos)
end)

-- Пит на коне (право первородства — FF.Horse; конюшни — StableHorse / StablePony / StableTainted; 19.10, открытый пункт
-- «режим на лошади»): FF в MC_POST_PLAYER_RENDER рисует коня и поверх — свой спрайт Питера из мультфильма (ноги — лист
-- ..._horsemode.png, голова — нарезка мультфильма), он ложился на нашего Пита. Колбэк FF — безымянная функция; узнаём её
-- по источнику в байткоде (string.dump: файл ffscripts/dead/fiend_b_skin_legitimate.lua — как у профайлера perfprobe),
-- снимаем и рисуем то же своим: коня из данных FF (data.HorseSprite, шаг ходьбы data.WalkFrame) и поверх — нашего Пита
-- всадником (поднят выше, чем у FF: наш Пит ниже мультяшного Питера).
local HORSE_OFF = { horse = -41, pony = -19, tainted = -64 }   -- подъём всадника (подобран по снимку в игре)
local function srcOf(fn)                            -- «файл:строка» функции из байткода Lua 5.4 (без debug)
	local ok, s = pcall(string.dump, fn)
	if not ok or type(s) ~= "string" or #s < 40 then return "?" end
	local pos = 33
	local function readU()
		local x = 0
		for _ = 1, 8 do
			local b = s:byte(pos)
			if not b then return 0 end
			pos = pos + 1
			x = x * 128 + (b & 0x7f)
			if b >= 0x80 then break end
		end
		return x
	end
	local n = readU()
	local src = "?"
	if n > 1 then src = s:sub(pos, pos + n - 2) end
	return (src:gsub("\\", "/"))
end
local horseFn
local function horseRender(_, player)
	if not isPeat(player) then return end
	local F = FiendFolio
	local data = F and F.GetEntityData and F:GetEntityData(player)
	if not data then return end
	local fs = player:GetSprite()
	if not data.Horsemode then
		fs.Offset = Vector.Zero
		return
	end
	-- всадник: наш Пит ниже мультяшного Питера — сидит выше (FF: −27 конь, −5 пони, −50 порченый конь; у нас на 14
	-- выше) и рисуется поверх коня целиком; туловище на спине закрывает подбородок — так и задумано (19.10, пользователь:
	-- «Нет все нормально вообще то»; «У тебя подбородок туловище просто закрыл / Нормально»)
	local offset = Vector(0, HORSE_OFF.horse)
	if data.Pony then offset = Vector(0, HORSE_OFF.pony) elseif data.Tainted then offset = Vector(0, HORSE_OFF.tainted) end
	fs.Offset = offset
	local pos = Game():GetRoom():WorldToScreenPosition(player.Position)
	local horse = data.HorseSprite
	if horse then
		if data.WalkFrame then horse:SetFrame("Walk", data.WalkFrame % 6) else horse:SetFrame("Idle", 0) end
		horse.FlipX = player.Velocity.X > 0
		horse:Render(pos, Vector.Zero, Vector.Zero)
	end
	-- поверх коня — весь Пит: тело (основная анимация) и голова (наложенная — при ходьбе)
	local s = sprite()
	if s then
		local anim = fs:GetAnimation()
		if pose(fs, s, anim, fs:GetFrame()) then s:Render(pos, Vector.Zero, Vector.Zero) end
		local ov = fs:GetOverlayAnimation()
		if walking(anim) and ov and ov ~= "" and pose(fs, s, ov, fs:GetOverlayFrame()) then
			s:Render(pos, Vector.Zero, Vector.Zero)
		end
	end
end
local function replaceHorse()
	if horseFn then return true end
	local F = FiendFolio
	if type(F) ~= "table" then return false end
	local okC, list = pcall(Isaac.GetCallbacks, ModCallbacks.MC_POST_PLAYER_RENDER)
	if not okC or type(list) ~= "table" then return false end
	for _, e in ipairs(list) do
		if e.Mod == F and type(e.Function) == "function" and srcOf(e.Function):find("fiend_b_skin_legitimate.lua", 1, true) then
			F:RemoveCallback(ModCallbacks.MC_POST_PLAYER_RENDER, e.Function)
			horseFn = horseRender
			mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, horseFn)
			return true
		end
	end
	return false
end
if ModCallbacks.MC_POST_MODS_LOADED then
	mod:AddCallback(ModCallbacks.MC_POST_MODS_LOADED, function()
		local ok, done = pcall(replaceHorse)
		Isaac.DebugString("[localfixes] Пит на коне — свой рисунок: " .. tostring(ok and done))
	end)
end

LOCALFIXES.PeatSkin = { sprite = sprite, isPeat = isPeat, replaceHorse = replaceHorse }
