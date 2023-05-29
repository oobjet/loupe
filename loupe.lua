-- loupe 
-- version from the manual 
--
-- tape heads definition
-- Record Head (1)
-- Dry Head (2)
-- FX Head (3)
-- Aditional Head (for multiply)
--

include("loupe/lib/controler")

  
-- global var
state = "reset"
loop_length = 0
dry_mix = 50
loop_mix = 50
fx_mix = 1
preserve = 100
fx_fbk = 0
rec_start = 0
rec_end = 0
dry_start = 0
dry_end = 0
fx_start = 0
fx_end = 0
dry_pos = 0
undo_flag = false

-------
-- init
-------
function init()
  audio.monitor_mono () 
  softcut_init()
  reset()
  softcut.event_position(update_pos)
end

function softcut_init()
for i = 1,3 do
    softcut.enable(i,1)
    softcut.buffer(i,1)
    softcut.level(i,1.0)
    softcut.loop(i,1)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, 100)
    softcut.position(i, 0)
    softcut.play(i,0)
    softcut.rate(i,1)
    softcut.rec_level(i,1.0)
    softcut.pre_level(i,0.0)
    -- softcut.level_input_cut(2,i,1.0)
    softcut.recpre_slew_time(i, 0.001) -- avoid clicks
    softcut.fade_time(i,0.001)
  end
  audio.level_adc_cut(1)
  -- reset filter on dry head
  softcut.pre_filter_dry(2,1.0)
  softcut.pre_filter_bp(2,0.0)
  -- softcut.level_input_cut(1,1,1.0)
end

function reset()
  softcut.buffer_clear_region(1, -1)
  -- start and end of each heads
  rec_start = 0
  rec_end = 0
  dry_start = 0
  dry_end = 0
  fx_start = 0
  fx_end = 0
  -- state
  state = "reset"
  -- level
  fx_fbk = 0
  -- dry/loop encoder at 12:00
  dry_mix = 50
  loop_mix = 50
  -- decay encoder at 5:00
  decay = 100
  -- fx
  fx_mix = 100
  -- global var
  loop_length = 0
end

  history = {} -- table stores value of start/end of each loop 
-- GAMES definitions (through Parameters)
-- parameters
--
-- FX definitions
---------------
-- audio matrix
---------------
-- Live input - delin
function delin (live_in)
  softcut.level_input_cut (1, 2, live_in)
end
-- live input - dry
function dry(a)
  audio.level_monitor(a/100)
end
-- decay - feed
function feed (a)
  -- softcut.level_cut_cut(2,1,a/100)
  softcut.pre_level(2,a/100)
  softcut.level_cut_cut(3,2,fx_fbk)
end
-- filters
function filters (band)
    -- set voice 2 (echo recorder) pre-filter
  -- set voice 2 dry level to 0.0
  softcut.pre_filter_dry(2,0.0)
  -- set voice 2 band pass level to 1.0 (full wet)
  softcut.pre_filter_bp(2,1.0)
  -- set voice 2 filter cutoff
  softcut.pre_filter_fc(2,band)
  -- set voice 2 filter rq (peaky)
  softcut.pre_filter_rq(2,1)
  -- softcut.level_cut_cut(2,2,1)
end

-- loop mix level
function loop (a)
  softcut.level (2,a/100)
  softcut.level (3,fx_mix/100*a)
end

-- REM : all functions exist in their normal, Quantized or Bar version
--------------------
-- one shot function
--------------------
function undo()
  -- undo previous function
  -- go back to previous start and end points
    ending()
  if (state == "sample" or state == "tails") and #history>2 then
    undo_flag = true
    dry_start = history[#history-2]
    dry_end = history[#history-1]
    table.remove(history)
    softcut.loop_start(2, dry_start)
    softcut.loop_end(2, dry_end)
    softcut.query_position(2)
  else
    -- 
  end
end

function trig()
  -- trig
end
function start()
  -- start
end
function reset()
  -- reset
end

-----------------------
-- two steps functions
-----------------------
-- starting a new function automatically close any current function (if function = true then call the function to close it)
function record()
  -- record the first loop
  if state ~= "record" then 
    init()
    -- switches
    delin(1)
    feed(0)
    loop(0)
    -- head state
    softcut.rec(2,1)
    -- softcut.play(2,1)
    -- looper state
    state="record"
    rec_time = util.time()
    print ("recording")
  elseif state == "record" then
    -- switches
    delin(0)
    feed(preserve)
    loop(loop_mix)
    -- loop start and end point
    dry_start = 0
    loop_length = util.time() - rec_time  
    dry_end = loop_length 
    -- first loop
    table.insert(history, 0) 
    play()
  end
  redraw()
end

function play()
  -- update history
  table.insert(history, dry_end) 
  -- define loop points
  rec_start = dry_start
  rec_end = dry_end 
  fx_start = dry_start
  fx_end = dry_end
  -- define audio matrix
  delin(0)
  loop(loop_mix)
  -- heads movement
  softcut.loop_start(2,dry_start)
  softcut.loop_end(2,dry_end)
  softcut.play(2,1)
  -- history
  -- sample OR tails
  if preserve == 100 then sample() end
  if preserve < 100 then tails() end
end

function tails()
  -- looper state
  state = "tails"
  feed(preserve)
  -- filters(1000)
  softcut.rec(2,1)
  print ("tails")
  redraw()
end

function sample()
  state = "sample"
  feed(100)
  softcut.rec(2,0)
  print ("sample")
  redraw()
end

function overdub()
  print "overdubing"
  -- overdub a layer
  if state ~= "overdub" then 
    -- end any running function (alternate ending)
    ending()
    -- copy loop to next slot
    softcut.buffer_copy_mono(1, 1, dry_start, dry_end, loop_length, 0, 0)
    -- move dry head to next slot (next() function)
    dry_start = dry_end
    dry_end = dry_start + loop_length
    softcut.loop_start(2, dry_start)
    softcut.loop_end(2, dry_end)
    softcut.query_position(2) 
    -- dryhead in overdub mode
    softcut.rec(2,1)
    -- inputs to recordhead
    feed(preserve)
    delin(1)
    loop(loop_mix)
    -- change state
    state = "overdub"
    redraw()
  elseif state == "overdub" then
    print "stop overdubing"
    -- play mode
    play()
  end
end

function replace()
  -- replace a sound
  if state ~= "replace" then 
    -- end any running function (alternate ending)
    ending()
    -- copy loop to next slot
    softcut.buffer_copy_mono(1, 1, dry_start, dry_end, loop_length, 0, 0)
    -- move dry head to next slot (next() function)
    dry_start = dry_end
    dry_end = dry_start + loop_length
    softcut.loop_start(2, dry_start)
    softcut.loop_end(2, dry_end)
    softcut.query_position(2) 
    -- dryhead in overdub mode with no preserve
    softcut.rec(2,1)
    -- inputs to recordhead
    feed(0)
    delin(1)
    loop(0)
    -- change state
    state = "replace"
    redraw()
  elseif state == "replace" then
    print "stop repalcing"
    -- play mode
    play()
  end
end

function substitute()
  -- substitute
  if state ~= "substitute" then 
    -- end any running function (alternate ending)
    ending()
    -- copy loop to next slot
    softcut.buffer_copy_mono(1, 1, dry_start, dry_end, loop_length, 0, 0)
    -- move dry head to next slot (next() function)
    dry_start = dry_end
    dry_end = dry_start + loop_length
    softcut.loop_start(2, dry_start)
    softcut.loop_end(2, dry_end)
    softcut.query_position(2) 
    -- dryhead in overdub mode with no preserve
    softcut.rec(2,1)
    -- inputs to recordhead
    feed(0)
    delin(1)
    loop(loop_mix)
    -- change state
    state = "substitute"
    redraw()
  elseif state == "substitute" then
    -- play mode
    play()
  end
end

function insert()
  -- insert
end
function instut()
  -- instut
end
function multiply()
  -- multiply
end
function stack()
  -- stack
end
function mute()
  -- mute
end
function pause()
  -- pause
end
function mutrig()
  -- mutrig
end

---------------------
-- internal functions
---------------------
function ending()
  if state ~= "samples" and state ~= "tails" then
    -- end any function started (alternate ending)
    if state == "record" then record() end
    if state == "overdub" then overdub() end
  end
end


function update_pos(index, position)
  dry_pos = position
  -- loop forward
  if undo_flag then
    softcut.position (2, dry_pos-loop_length)
    print "undoing"
    undo_flag = false
  else
    softcut.position(2, dry_pos+loop_length)
    print "forward"
  end
  
    -- DEBUG
    print (dry_start.."-"..dry_pos+loop_length.."-"..dry_end)
end
  

-----
-- fx 
-----
--
--
-- dry/loop encoder

function enc(n,d)
  -- encoder actions: n = number, d = delta
  -- dry / loop
  if n == 2 then
    dry_mix = util.clamp(dry_mix+d,0, 100)
    loop_mix = 100 - dry_mix
    -- adjust dry/loop pot
    loop(loop_mix)
    dry(dry_mix)
    redraw()
  end
-- preserve encoder
  if n == 3 then
    preserve = util.clamp(preserve+d,0,100)
    -- sample OR tails
    if preserve==100 and state=="tails" then 
      sample()
    elseif preserve < 100 and state =="sample" then 
      tails()
    end
    
    -- adjust feed
    feed(preserve)
    redraw()
  end
end
---------
-- scroll
---------
function scroll()
  -- go back in history (go to the previous interval in memory table)
end

---------
-- screen
---------

function redraw()
  -- screen redraw
  screen.clear()
  screen.move(10,10)
  screen.text("state : "..state)
  screen.move(10,20)
  screen.text("loop_length : "..loop_length)
  -- pot position
  screen.move(10,60)
  screen.text("dry/loop "..dry_mix)
  screen.move(65,60)
  screen.text("preserve"..preserve)
  
  screen.update()
end
