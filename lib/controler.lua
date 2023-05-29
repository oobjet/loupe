-- foot controller
-- midi notes from 60 to 69
-- 

m = midi.connect() -- midi input
local func = {"record", "overdub"}

m.event = function (data)
  local d = midi.to_msg(data)
  if (d.note == 60) and (d.type == "note_on") then sw1_on() end
  if (d.note == 60) and (d.type == "note_off") then sw1_off() end
  if (d.note == 61) and (d.type == "note_on") then sw2_on() end
  if (d.note == 61) and (d.type == "note_off") then sw2_off() end
  if (d.note == 62) and (d.type == "note_on") then sw3_on() end
  if (d.note == 62) and (d.type == "note_off") then sw3_off() end
  if (d.note == 63) and (d.type == "note_on") then sw4_on() end
  if (d.note == 63) and (d.type == "note_off") then sw4_off() end
  if (d.note == 64) and (d.type == "note_on") then sw5_on() end
  if (d.note == 64) and (d.type == "note_off") then sw5_off() end
end 

-- PARAMETERS
-- switch assignation
params:add_option("switch 1", "sw1", {"record", "overdub", "replace", "substitute", "undo"}, 1)
params:add_option("switch 2", "sw2", {"record", "overdub", "replace", "substitute", "undo"}, 2)
params:add_option("switch 3", "sw4", {"record", "overdub", "replace", "substitute", "undo"}, 3)
params:add_option("switch 4", "sw4", {"record", "overdub", "replace", "substitute", "undo"}, 4)
params:add_option("switch 5", "sw5", {"record", "overdub", "replace", "substitute", "undo"}, 5)

function sw1_on()
  print"switch1_on" 
  -- call function asign to switch1
  if params:get("switch 1") == 1 then record() end
  -- params:get("switch 1")()
  -- func[params:get("switch 1")]()
end
function sw2_on()
  print"switch2_on" 
  if params:get("switch 2") == 2 then overdub() end
end
function sw3_on()
  print"switch3_on" 
  if params:get("switch 3") == 3 then replace() end
end
function sw4_on()
  print"switch4_on" 
  if params:get("switch 4") == 4 then substitute() end
end
function sw5_on()
  print"switch5_on" 
  if params:get("switch 5") == 5 then undo() end
end

function sw1_off()
  --
  print("switch1_off")
end
function sw2_off()
end

function sw3_off()
end

function sw4_off()
end


function sw5_off()
end