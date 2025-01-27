-- s_kria.lua
-- A reimplementation of the Kria sequencer for Seamstress
-- Based on the monome Kria module
--
-- @rbrt-fm
-- v1.0.0 @ 2025-01-27

-- Requirements
util = require('util')
grid = require('grid')

-- Global data structure
data = {
    playing = false,
    bpm = 120,
    active_track = 1,
    active_page = 1,
    active_scale = 1,
    dirty = true,
    tracks = {}
}

-- Constants
MAX_TRACKS = 4
PAGES = {
    TRIGGER = 1,
    NOTE = 2,
    OCTAVE = 3,
    GATE = 4,
    SCALE = 5,
    PATTERN = 6
}
page_names = {"TRIGGER", "NOTE", "OCTAVE", "GATE", "SCALE", "PATTERN"}

-- Scales
SCALES = {
    {name = "Major", intervals = {0, 2, 4, 5, 7, 9, 11}},
    {name = "Minor", intervals = {0, 2, 3, 5, 7, 8, 10}},
    {name = "Pentatonic", intervals = {0, 2, 4, 7, 9}},
    {name = "Blues", intervals = {0, 3, 5, 6, 7, 10}}
}

-- Initialize tracks
for i = 1, MAX_TRACKS do
    data.tracks[i] = {
        playing = false,
        position = 1,
        length = 16,
        triggers = {},
        notes = {},
        octaves = {},
        gates = {}
    }
    -- Initialize arrays for each track
    for j = 1, 16 do
        data.tracks[i].triggers[j] = false
        data.tracks[i].notes[j] = 1
        data.tracks[i].octaves[j] = 0
        data.tracks[i].gates[j] = 100
    end
end

-- Grid initialization and handling
local g = nil
function init_grid()
    g = grid.connect(1)  -- Try to connect to first available grid
    if g then
        print("Grid connected:", g.name)
        g.key = function(x, y, z)
            grid_key(x, y, z)  -- Forward to our grid handler
        end
    else
        print("No grid found")
    end
end

-- Grid event handler
function grid_key(x, y, z)
    if not g then return end  -- Guard against nil grid
    
    if z == 1 then
        if y == 8 then  -- Bottom row - track selection
            if x <= MAX_TRACKS then
                data.active_track = x
                data.dirty = true
            end
        else  -- Pattern editing
            local track = data.tracks[data.active_track]
            if data.active_page == PAGES.TRIGGER then
                if x <= track.length then
                    track.triggers[x] = not track.triggers[x]
                    data.dirty = true
                end
            elseif data.active_page == PAGES.NOTE then
                if x <= track.length and y <= 7 then
                    track.notes[x] = y
                    data.dirty = true
                end
            elseif data.active_page == PAGES.OCTAVE then
                if x <= track.length and y <= 7 then
                    track.octaves[x] = y - 4  -- Center around 0
                    data.dirty = true
                end
            elseif data.active_page == PAGES.GATE then
                if x <= track.length and y <= 7 then
                    track.gates[x] = y * 15  -- Scale to 0-100%
                    data.dirty = true
                end
            elseif data.active_page == PAGES.SCALE then
                if y <= #SCALES then
                    data.active_scale = y
                    data.dirty = true
                end
            end
        end
    end
end

-- Event handlers
function keyboard(name, data_event)
    print("Keyboard event:", name, data_event)  -- Debug print
    if data_event.state == 1 then  -- key down
        if data_event.name == "space" then
            data.playing = not data.playing
            data.tracks[data.active_track].playing = data.playing
            data.dirty = true
        elseif data_event.name == "up" then
            data.bpm = util.clamp(data.bpm + 1, 20, 300)
            data.dirty = true
        elseif data_event.name == "down" then
            data.bpm = util.clamp(data.bpm - 1, 20, 300)
            data.dirty = true
        elseif data_event.name == "left" then
            data.active_track = util.clamp(data.active_track - 1, 1, MAX_TRACKS)
            data.dirty = true
        elseif data_event.name == "right" then
            data.active_track = util.clamp(data.active_track + 1, 1, MAX_TRACKS)
            data.dirty = true
        elseif data_event.name == "tab" then
            data.active_page = (data.active_page % #page_names) + 1
            data.dirty = true
        end
    end
end

function mouse(name, data_event)
    print("Mouse event:", name, data_event)  -- Debug print
    if name == "click" then
        if data_event.state == 1 then  -- mouse down
            if data_event.button == 1 then  -- left click
                if data_event.y > 45 and data_event.y < 55 then
                    data.bpm = util.clamp(data.bpm + (data_event.y < 50 and 1 or -1), 20, 300)
                    data.dirty = true
                elseif data_event.y > 25 and data_event.y < 35 then
                    data.active_track = util.clamp(data.active_track + (data_event.y < 30 and 1 or -1), 1, MAX_TRACKS)
                    data.dirty = true
                elseif data_event.y > 35 and data_event.y < 45 then
                    data.active_page = util.clamp(data.active_page + (data_event.y < 40 and 1 or -1), 1, #page_names)
                    data.dirty = true
                end
            elseif data_event.button == 3 then  -- right click
                data.playing = not data.playing
                data.tracks[data.active_track].playing = data.playing
                data.dirty = true
            end
        end
    elseif name == "wheel" then
        if data_event.y > 45 and data_event.y < 55 then
            data.bpm = util.clamp(data.bpm + data_event.delta, 20, 300)
        elseif data_event.y > 25 and data_event.y < 35 then
            data.active_track = util.clamp(data.active_track + math.sign(data_event.delta), 1, MAX_TRACKS)
        elseif data_event.y > 35 and data_event.y < 45 then
            data.active_page = util.clamp(data.active_page + math.sign(data_event.delta), 1, #page_names)
        end
        data.dirty = true
    end
end

function redraw()
    screen.clear()
    screen.level(15)
    
    -- Draw header
    screen.move(2, 10)
    screen.text("kria")
    
    -- Draw transport state
    screen.move(120, 10)
    screen.text(data.playing and ">" or "||")
    
    -- Draw track selection
    screen.level(4)
    screen.move(2, 30)
    screen.text("[                  ]")
    screen.level(15)
    screen.move(2, 30)
    screen.text(string.format("Track: %d <click/scroll>", data.active_track))
    
    -- Draw page selection
    screen.level(4)
    screen.move(2, 40)
    screen.text("[                  ]")
    screen.level(15)
    screen.move(2, 40)
    screen.text(string.format("Page: %s <click/scroll>", page_names[data.active_page]))
    
    -- Draw BPM control
    screen.level(4)
    screen.move(2, 50)
    screen.text("[                  ]")
    screen.level(15)
    screen.move(2, 50)
    screen.text(string.format("BPM: %.1f <click/scroll>", data.bpm))
    
    -- Draw scale info when on scale page
    if data.active_page == PAGES.SCALE then
        screen.move(2, 60)
        screen.text(string.format("Scale: %s", SCALES[data.active_scale].name))
    end
    
    screen.update()
end

function draw_grid()
    if not g then return end  -- Guard against nil grid
    
    g:all(0)
    local track = data.tracks[data.active_track]
    
    -- Draw pattern
    for x = 1, 16 do
        if data.active_page == PAGES.TRIGGER then
            if track.triggers[x] then
                g:led(x, 1, 15)
            end
        elseif data.active_page == PAGES.NOTE then
            g:led(x, track.notes[x], 15)
        elseif data.active_page == PAGES.OCTAVE then
            g:led(x, track.octaves[x] + 4, 15)  -- Center around middle
        elseif data.active_page == PAGES.GATE then
            g:led(x, math.floor(track.gates[x] / 15), 15)
        end
        
        -- Show playhead
        if x == track.position and track.playing then
            g:led(x, data.active_page == PAGES.TRIGGER and 1 or track.notes[x], 15)
        end
    end
    
    -- Draw track selection on bottom row
    for i = 1, MAX_TRACKS do
        g:led(i, 8, i == data.active_track and 15 or 4)
    end
    
    -- Draw scale selection when on scale page
    if data.active_page == PAGES.SCALE then
        for i = 1, #SCALES do
            g:led(1, i, i == data.active_scale and 15 or 4)
        end
    end
    
    pcall(function() g:refresh() end)  -- Safely try to refresh grid
end

-- Helper functions
function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

function init()
    print("Init started")
    
    -- Initialize grid
    init_grid()
    
    -- Test event generation
    clock.run(function()
        clock.sleep(1)
        print("Sending test event...")
        keyboard("key", {name = "space", state = 1})
        print("Test event sent")
    end)

    -- Start UI refresh clock
    clock.run(function()
        while true do
            clock.sleep(1/15)
            if data.dirty then
                redraw()
                if g then  -- Only try to draw grid if it exists
                    draw_grid()
                end
                data.dirty = false
            end
        end
    end)

    -- Start sequencer clock
    clock.run(function()
        while true do
            clock.sleep(60 / data.bpm / 4)
            if data.playing then
                for t = 1, MAX_TRACKS do
                    if data.tracks[t].playing then
                        data.tracks[t].position = (data.tracks[t].position % data.tracks[t].length) + 1
                    end
                end
                data.dirty = true
            end
        end
    end)

    print("Init completed")
    redraw()
    if g then  -- Only try to draw grid if it exists
        draw_grid()
    end
end