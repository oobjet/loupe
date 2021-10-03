-- loupe : innovative looper
-- v1.0.0 @objet
-- local version

engine.name = 'PolySub'
m = midi.connect() -- midi input
recordheadpos = 0
playheadpos = 0
fxheadpos = 0

playheadstart = 0
playheadstop = 0
recordheadstart = 0
recordheadstop = 0
fxheadstart = 0
fxheadstop = 0

loop_length = 0
loop_start = 0
loop_stop = 100

state = "reset"
fx_state = "bypass"
next_function=""
tempo = 120

decay = 0
dryloopmix = 0.5

timer = 0

--parameters
-- quantization
params:add_option("quantization", "quantization", {"1", "1/2", "1/4", "1/8", "1/16"}, 1) 
params:add_option("record_q", "record quantization", {"n", "B", "Q"}, 1) 
params:add_option("overdub_q", "overdub quantization", {"n", "B", "Q"}, 3) 
params:add_option("multiply_q", "multipy quantization", {"n", "B", "Q"}, 1) 
params:add_option("fx_q", "fx quantization", {"n", "B", "Q"}, 1) 
-- switch
params:add_option("record_s", "record switch", {"latch", "sustain"}, 1)
params:add_option("overdub_s", "overdub switch", {"latch", "sustain"}, 1)
params:add_option("multiply_s", "multiply switch", {"latch", "sustain"}, 1)
params:add_option("fx_s", "fx switch", {"latch", "sustain"}, 2)
-- fx
params:add_option("fx_speed", "fx speed", {"-2", "-1", "1", "2"}, 4)
params:add_number("fx_level", "fx level", 0, 100, 100)
params:add_number("fx_overdub", "fx overdub level", 0, 100, 50)
-- midi
params:add{type = "number", id = "record_midi", name = "record midi note", min = 60, max = 99, default = 60}
params:add{type = "number", id = "overdub_midi", name = "overdub midi note", min = 60, max = 99, default = 61}
params:add{type = "number", id = "multiply_midi", name = "multipy midi note", min = 60, max = 99, default = 62}
params:add{type = "number", id = "fx_midi", name = "fx midi note", min = 60, max = 99, default = 63}

function init()
  -- initialization
  -- DRYHEAD (recordhead / playhead) = 1
  -- additional playhead = 2
  -- FXHEAD (readfx) = 3
  for i = 1,3 do
    softcut.enable(i,1)
    softcut.buffer(i,1)
    softcut.level(i,1.0)
    softcut.loop(i,1)
    softcut.loop_start(i,0)
    softcut.loop_end(i,100)
    softcut.position(i,0)
    softcut.play(i,0)
    softcut.fade_time(i,0.01)
    -- softcut.rate(i,1)
    softcut.rec_level(i,1.0)
    softcut.pre_level(i,0.0)
    softcut.pre_filter_dry(i,0.9)
  end
  audio.level_adc_cut(1)
 -- softcut.level_input_cut(1,1,0.9)
  softcut.level_input_cut(2,1,1.0)
  softcut.buffer_clear()
  state="reset"
  -- softcut.event_position(update_positions)
  softcut.phase_quant(1,0.01)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
end

function update_positions(i, pos)
  if i == 1 then
    recordheadpos = pos
  elseif i == 2 then
    playheadpos = pos
  end
end

function tempo_calc()
  -- tempo
  tempo = 3600/8/loop_length
  while tempo<40 do
    tempo = tempo * 2
  end
  while tempo>240 do
    tempo = tempo / 2
  end
  params:set("clock_tempo", tempo)
end

function B_clock()
  while true do
    clock.sync(1/2)
    if next_function == "multiply" then multiply(); next_function = "" end
    if next_function == "overdub" then overdub(); next_function = "" end
  end
end

function record()
  -- record
  -- first record ?
  if state == "reset" then
    state = "recording"
    redraw()
    softcut.rec(1,1) -- recordhead on
  elseif state == "recording" then
    state = "playing"
    loop_length = recordheadpos
    softcut.rec(1,0) -- recordhead off
    softcut.position(1,0) -- start playing from the start
    softcut.loop_end(1,loop_length) -- define end point
    softcut.play(1,1) -- playhead on
    recordheadstart = 0
    recordheadstop = loop_length
    -- tempo
    tempo_calc()
    -- clocks
    -- B_clock_id = clock.run(B_clock)
    redraw()
  elseif state == "playing" then
    init()
    record()
    redraw()
    -- clock
    -- clock.cancel(B_clock_id)
  elseif state == "overdubing" then
    overdub()
    record()
  elseif state == "multiplying" then
    multiply()
    record()
  end
end

function quantize(command)
    if params:get(command.."_q") == 2 then
        clock.sync(4)
    elseif params:get(command.."_q") == 3 then
        clock.sync(1/4)
    end
end

function overdub()
  -- quantization
  quantize("overdub")
  -- if params:get("overdub_q") == 2 then
  --   clock.sync(4)
  -- elseif params:get("overdub_q") == 3 then
  --   clock.sync(1/4)
  -- end
  -- finish recording process before entering overdub 
  if state == "recording" then
    record ()
  elseif state == "playing" then
    state = "overdubing"
    redraw()
    softcut.buffer_copy_mono(1, 1, recordheadstart, recordheadstop, loop_length, 0, 0, 0) -- copy buffer to next slot
    -- play head jump forward
    softcut.position(1,recordheadpos + loop_length)
    -- play head goes into overdub mode
    softcut.play(1,1)
    softcut.rec(1,1)
    softcut.pre_level(1, 1-decay)
    -- redefine start and stop
    recordheadstart = recordheadstart + loop_length
    recordheadstop = recordheadstart + loop_length
    softcut.loop_start(1,recordheadstart)
    softcut.loop_end(1,recordheadstop)
    redraw()
  elseif state == "overdubing" then
    -- stop overdub
    state = "playing"
    -- play head goes into play mode
    softcut.rec(1,0)
    redraw()
    nextslot ()
  elseif state == "recording" then
    record()
    overdub()
  elseif state == "reset" then
    record()
  elseif state == "multiplying" then
    multiply()
    overdub()
  end
end

function multiply()
  quantize("multiply")
  if state == "playing" then
    state = "multiplying"
    -- addtional playhead read loop continuesly
    softcut.play(2,1)
    softcut.loop_start (2, recordheadstart)
    softcut.loop_end (2, recordheadstop)
    softcut.position(2, recordheadpos)
    -- recordhead move to next slot (+ looplength)
    recordheadstart = recordheadstart + loop_length
    recordheadstop = recordheadstop + 100
    -- recordhead record live input + playhead
    softcut.level_cut_cut(2,1,0.5)
    softcut.pre_level(1,0.0)
    softcut.rec(1,1)
    softcut.play(1,0)
    softcut.loop_start (1, recordheadstart)
    softcut.loop_end (1, recordheadstop)
    softcut.position(1, recordheadstart)
    -- loop_start is redefined
    loop_start = recordheadstart
    redraw()
  elseif state == "multiplying" then
    state = "playing"
    loop_stop = recordheadpos
    loop_length = loop_stop - loop_start
    tempo_calc() -- calculate new tempo
    recordheadstart = loop_start
    recordheadstop = loop_stop
    softcut.loop_start(1, recordheadstart)
    softcut.loop_end(1, recordheadstop)
    -- recordhead goes back into playhead
    softcut.rec(1,0)
    softcut.play(1,1)
    softcut.position(1, recordheadstart)
    -- playhead is stopped
    softcut.play(2,0)
    redraw()
  elseif state == "recording" then
    record()
    multiply()
  elseif state == "reset" then
    record()
  elseif state == "overdubing" then
    overdub()
    multiply()
  end
end

function fx()
  quantize("fx")
  -- fx head plays at speed predifined in preset
  if fx_state == "bypass" then
    fx_state = "on"
    softcut.position(3,recordheadpos)
    softcut.play(3,1)
    softcut.rate(3,-2)
    softcut.loop_start(3, recordheadstart)
    softcut.loop_end(3, recordheadstop)
    -- overdub in fx
    softcut.level_cut_cut(3,1,params:get("fx_overdub")/100)
    -- fx level
    softcut.level(3, params:get("fx_level")/100) 
    
    redraw()
  elseif fx_state == "on" then
    fx_state = "bypass"
    softcut.play(3,0)
    redraw()
  end
end


function nextslot()
  -- current slot archived
  -- recordhead moves to next slot
  -- recordhead on (copying playhead) ready for next action
end

function undo()
  -- recordhead goes backward one slot
  -- playhead goes backward one slot
  state = "playing"
end

function forward(jump)
  -- move forward into memory
  -- recordhead advance 
  recordheadstart = recordheadstart + jump
  recordheadstop = recordheadstop + jump
  recordheadpos = recordheadpos + jump
  softcut.loop_start(1, recordheadstart)
  softcut.loop_end(1, recordheadstop)
  softcut.position(1, recordheadpos)
end

function key(n,z)
  -- key actions: n = number, z = state
  if z == 1 then
    if n==2 then 
      record()
    elseif n==1 then
      next_function = "multiply"
    elseif n==3 then
      next_function = "overdub"
    end
  end
end

function enc(n,d)
  -- encoder actions: n = number, d = delta
  if n == 2 then
    decay=util.clamp(decay+d/10,0, 1)
    softcut.pre_level(2,1-decay)
    redraw()
  elseif n == 3 then
    recordheadstart = recordheadstart+d*loop_length
    recordheadstop = recordheadstop+d*loop_length
    softcut.loop_start(1, recordheadstart)
    softcut.loop_end(1, recordheadstop)
    softcut.position(1, recordheadpos+d*loop_length)
    redraw()
  end
end

function redraw()
  -- screen redraw
  screen.clear()
  screen.move(10,10)
  screen.text(state)
  screen.move(60,10)
  screen.text(fx_state)
  screen.move(10,20)
  screen.text("loop_length")
  screen.move(60,20)
  screen.text(loop_length)
  screen.move(10,30)
  screen.text("start")
  screen.move(60,30)
  screen.text(recordheadstart)
  screen.move(10,40)
  screen.text("end")
  screen.move(60,40)
  screen.text(recordheadstop)
  screen.move(10,50)
  screen.text("decay")
  screen.move(60,50)
  screen.text(decay)
  
  screen.update()
end
-- midi pilot
m.event = function (data)
  local d = midi.to_msg(data)
  if (d.note == params:get("record_midi")) and ((d.type == "note_on") or ((d.type == "note_off") and (params:get("record_s") == 2))) then
      clock.run(record)
  elseif (d.note == params:get("overdub_midi")) and ((d.type == "note_on") or ((d.type == "note_off") and (params:get("overdub_s") == 2))) then
      clock.run(overdub)
  elseif (d.note == params:get("multiply_midi")) and ((d.type == "note_on") or ((d.type == "note_off") and (params:get("multiply_s") == 2))) then
      clock.run(multiply)
  elseif (d.note == params:get("fx_midi")) and ((d.type == "note_on") or ((d.type == "note_off") and (params:get("fx_s") == 2))) then
      clock.run(fx)
  end 
  
end


function cleanup()
  -- deinitialization
end
