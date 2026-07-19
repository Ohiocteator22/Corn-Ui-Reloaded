function Nullscape()
  loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Nullscape.lua"))()
end

function LOS()
  loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Legends%20of%20speed.lua"))()
end

function Area51()
  loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Area%2051.lua"))()
end

function TOH()
  loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/TowerOfHell.lua"))()
end

function Rivals()
  loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Scripts/Rivals.lua"))()
--functions only--
if game.PlaceId == 3101667897 then
  LOS()
end

if game.PlaceId == 100588763114828 or game.PlaceId == 129279692364812 then
  Nullscape()
end

if game.PlaceId == 2092166489 then
  Area51()
end

if game.PlaceId == 1962086868 then
  TOH()
end

if game.PlaceId == 17625359962 then
    Rivals()
end



