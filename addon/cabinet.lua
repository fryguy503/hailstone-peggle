-- Copyright 2026 fryguy503. All rights reserved. See LICENSE.
local Cabinet = {}

local WIDTH, HEIGHT = 1100, 740
local BOARD_X, BOARD_Y = 20, 118

local color = {
    ink = {0.035, 0.055, 0.087}, panel = {0.065, 0.095, 0.143},
    inset = {0.041, 0.061, 0.098}, edge = {0.19, 0.25, 0.34},
    text = {0.93, 0.95, 0.98}, muted = {0.62, 0.70, 0.78},
    gold = {1.00, 0.75, 0.36}, goldDeep = {0.91, 0.50, 0.21},
    green = {0.43, 0.91, 0.68}, red = {1.00, 0.56, 0.48},
    dark = {0.012, 0.020, 0.037}, white = {1, 1, 1},
}

local gems = {
    blue = {{0.20, 0.62, 0.88}, {0.51, 0.86, 1.00}, {0.09, 0.28, 0.50}},
    orange = {{0.99, 0.53, 0.22}, {1.00, 0.84, 0.44}, {0.51, 0.21, 0.12}},
    green = {{0.29, 0.77, 0.50}, {0.62, 1.00, 0.71}, {0.10, 0.40, 0.32}},
    purple = {{0.67, 0.43, 0.91}, {0.91, 0.73, 1.00}, {0.33, 0.17, 0.53}},
}

local scenes = {
    {{0.07, 0.18, 0.19}, {0.035, 0.09, 0.15}, {0.36, 0.79, 0.61}},
    {{0.20, 0.11, 0.22}, {0.10, 0.07, 0.16}, {0.83, 0.49, 0.67}},
    {{0.09, 0.15, 0.28}, {0.04, 0.07, 0.19}, {0.46, 0.69, 0.99}},
    {{0.21, 0.15, 0.095}, {0.095, 0.09, 0.12}, {0.94, 0.69, 0.36}},
    {{0.07, 0.16, 0.27}, {0.04, 0.11, 0.14}, {0.39, 0.81, 0.87}},
    {{0.16, 0.11, 0.28}, {0.07, 0.08, 0.16}, {0.70, 0.55, 0.94}},
    {{0.23, 0.10, 0.13}, {0.06, 0.09, 0.17}, {1.00, 0.55, 0.36}},
    {{0.09, 0.18, 0.24}, {0.04, 0.08, 0.17}, {0.68, 0.86, 1.00}},
    {{0.21, 0.17, 0.10}, {0.045, 0.15, 0.14}, {0.90, 0.79, 0.39}},
    {{0.18, 0.12, 0.13}, {0.06, 0.08, 0.12}, {0.91, 0.49, 0.45}},
    {{0.19, 0.10, 0.25}, {0.09, 0.07, 0.19}, {0.86, 0.57, 0.98}},
    {{0.23, 0.16, 0.09}, {0.11, 0.08, 0.14}, {1.00, 0.73, 0.39}},
}

local function formatScore(n)
    local value = tostring(math.floor(n or 0))
    return value:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

local function at(list, id)
    for index, item in ipairs(list) do
        if item.id == id then return index, item end
    end
    return 1, list[1]
end

local function canvas(ui, x, y, s)
    local function rect(a, b, c, d, t, alpha, radius)
        ui.DrawRectFilled(x+a*s, y+b*s, x+c*s, y+d*s, t[1], t[2], t[3], alpha or 1, (radius or 0)*s)
    end
    local function edge(a, b, c, d, t, alpha, radius, weight)
        ui.DrawRect(x+a*s, y+b*s, x+c*s, y+d*s, t[1], t[2], t[3], alpha or 1,
            (radius or 0)*s, math.max(1, (weight or 1)*s))
    end
    local function gradient(a, b, c, d, top, bottom)
        ui.DrawRectGradient(x+a*s, y+b*s, x+c*s, y+d*s, top[1], top[2], top[3], 1,
            bottom[1], bottom[2], bottom[3], 1)
    end
    local function line(a, b, c, d, t, alpha, weight)
        ui.DrawLine(x+a*s, y+b*s, x+c*s, y+d*s, t[1], t[2], t[3], alpha or 1,
            math.max(1, (weight or 1)*s))
    end
    local function dot(a, b, radius, t, alpha)
        ui.DrawCircleFilled(x+a*s, y+b*s, radius*s, t[1], t[2], t[3], alpha or 1)
    end
    local function ring(a, b, radius, t, alpha, weight)
        ui.DrawCircle(x+a*s, y+b*s, radius*s, t[1], t[2], t[3], alpha or 1,
            math.max(1, (weight or 1)*s))
    end
    local function triangle(a, b, c, d, e, f, t, alpha)
        ui.DrawTriangleFilled(x+a*s, y+b*s, x+c*s, y+d*s, x+e*s, y+f*s,
            t[1], t[2], t[3], alpha or 1)
    end
    local function label(a, b, value, size, tint, alpha)
        local t = tint or color.text
        ui.DrawText(x+a*s, y+b*s, t[1], t[2], t[3], alpha or 1, value, math.max(8, size*s))
    end
    local function position(a, b)
        ui.SetCursorScreenPos(x+a*s, y+b*s)
    end
    local function button(id, value, a, b, w, h, accent, disabled)
        position(a, b)
        ui.BeginDisabled(disabled == true)
        local hit = ui.InvisibleButton('##'..id, w*s, h*s, ui.ButtonFlags.EnableNav)
        local hover = ui.IsItemHovered() or ui.IsItemFocused()
        ui.EndDisabled()
        local tint = accent and color.gold or color.text
        rect(a, b, a+w, b+h, accent and color.gold or color.panel,
            accent and (hover and 0.26 or 0.15) or (hover and 0.98 or 0.65), 7)
        edge(a, b, a+w, b+h, hover and tint or (accent and color.goldDeep or color.edge),
            disabled and 0.30 or (hover and 0.96 or 0.68), 7)
        label(a+12, b+(h-16)/2, value, 16, tint, disabled and 0.38 or 1)
        return hit and not disabled
    end
    return {rect=rect, edge=edge, gradient=gradient, line=line, dot=dot, ring=ring,
        triangle=triangle, label=label, position=position, button=button, x=x, y=y, scale=s}
end

local function panel(c, x, y, w, h)
    c.rect(x, y+3, x+w, y+h+3, color.dark, 0.8, 10)
    c.rect(x, y, x+w, y+h, color.panel, 1, 10)
    c.edge(x, y, x+w, y+h, color.edge, 0.85, 10)
end

local function header(c, state)
    c.rect(0, 0, WIDTH, HEIGHT, color.ink, 1, 8)
    c.gradient(0, 0, WIDTH, 104, color.panel, color.ink)
    c.line(20, 104, WIDTH-20, 104, color.edge, 0.95)
    c.line(20, 104, 206, 104, color.goldDeep, 0.84, 2)

    c.dot(48, 52, 26, color.gold, 0.11)
    c.ring(48, 52, 24, color.gold, 0.54)
    c.ring(48, 52, 18, color.gold, 0.30)
    c.triangle(48, 32, 66, 52, 48, 72, color.goldDeep, 0.85)
    c.triangle(48, 32, 30, 52, 48, 72, color.gold, 0.95)
    c.dot(48, 52, 5, color.ink)
    c.label(84, 27, 'PEGGLE', 34)
    c.label(86, 66, 'HAILSTONE ARCADE', 13, color.gold)

    if c.button('play', 'Play', 618, 34, 76, 34, state.page == 'play') then state.page = 'play' end
    if c.button('duels', 'Friend duels', 704, 34, 130, 34, state.page == 'duel') then state.page = 'duel' end
    if c.button('records', 'Records', 844, 34, 104, 34, state.page == 'records') then state.page = 'records' end
    if c.button('help', 'How to play', 958, 34, 122, 34, state.page == 'help') then state.page = 'help' end
end

local function sceneDetail(c, x, y, w, h, tint, index)
    if index == 1 then
        for _, offset in ipairs({62, 111, w-111, w-62}) do
            local bend = offset < w/2 and 1 or -1
            c.line(x+offset, y+h-40, x+offset+24*bend, y+187, tint, 0.13, 2)
            for branch = 1, 4 do
                local tip = y+177+branch*50
                c.line(x+offset+15*bend, tip+49, x+offset+67*bend, tip, tint, 0.12, 2)
                c.line(x+offset+67*bend, tip, x+offset+41*bend, tip+49, tint, 0.07)
            end
        end
    elseif index == 2 then
        for gear = 1, 2 do
            local gx, gy, radius = x+gear*(w/3), y+154+gear*93, 78+gear*17
            c.ring(gx, gy, radius, tint, 0.17, 2)
            c.ring(gx, gy, radius*0.78, tint, 0.1)
            for tooth = 0, 15 do
                local a = tooth*math.pi/8
                c.line(gx+math.cos(a)*radius, gy+math.sin(a)*radius,
                    gx+math.cos(a)*(radius+10), gy+math.sin(a)*(radius+10), tint, 0.19, 5)
            end
        end
    elseif index == 3 then
        for constellation = 0, 2 do
            local sx, sy = x+60+constellation*250, y+116+constellation%2*52
            local points = {{0, 23}, {31, 3}, {74, 48}, {111, 32}, {141, 67}}
            for i, point in ipairs(points) do
                local dx, dy = sx+point[1], sy+point[2]
                c.dot(dx, dy, i % 2 == 0 and 2.4 or 1.4, tint, 0.38)
                if i > 1 then c.line(sx+points[i-1][1], sy+points[i-1][2], dx, dy, tint, 0.15) end
            end
        end
    elseif index == 4 then
        for tower = 0, 8 do
            local tx, floor = x+19+tower*83, y+h-38
            local peak = floor-(144+math.min(tower, 8-tower)*34)
            c.line(tx, floor, tx, peak+32, tint, 0.16)
            c.line(tx, peak+32, tx+19, peak+32, tint, 0.16)
            c.line(tx+19, peak+32, tx+39, peak, tint, 0.16)
            c.line(tx+39, peak, tx+60, peak+32, tint, 0.16)
            c.line(tx+60, peak+32, tx+71, peak+32, tint, 0.16)
            c.line(tx+71, peak+32, tx+71, floor, tint, 0.16)
        end
    elseif index == 5 then
        for wave = 1, 5 do
            local lastX, lastY = x+11, y+240+wave*40+math.sin(wave)*21
            for point = 1, 24 do
                local px = x+11+point*(w-22)/24
                local py = y+240+wave*40+math.sin(wave+point*0.32)*21
                c.line(lastX, lastY, px, py, tint, 0.15)
                lastX, lastY = px, py
            end
        end
    elseif index == 6 then
        for crystal = 0, 6 do
            local sx, floor = x+67+crystal*104, y+h-39
            local peak = floor-159-(crystal*67 % 153)
            c.triangle(sx-40, floor, sx-10, peak, sx+29, floor, tint, 0.08)
            c.line(sx-40, floor, sx-10, peak, tint, 0.22)
            c.line(sx-10, peak, sx+29, floor, tint, 0.16)
            c.line(sx-10, peak, sx-1, floor, tint, 0.13)
        end
    elseif index == 7 then
        local pier = y+h-96
        c.line(x+38, pier, x+w-38, pier, tint, 0.27, 2)
        for sail = 0, 4 do
            local mastX = x+75+sail*146
            local top = pier-164-(sail % 2)*58
            c.triangle(mastX, top, mastX, pier-21, mastX+92, pier-21, tint, 0.09)
            c.line(mastX, top, mastX, pier, tint, 0.24)
            c.line(mastX, top, mastX+92, pier-21, tint, 0.17)
        end
    elseif index == 8 then
        for pane = 0, 4 do
            local center, foot = x+w*0.5, y+h-62
            local height, inset = 356-pane*44, 186-pane*28
            c.triangle(center, foot-height, center-inset, foot, center+inset, foot, tint, 0.045)
            c.line(center, foot-height, center-inset, foot, tint, 0.16, 2)
            c.line(center, foot-height, center+inset, foot, tint, 0.16, 2)
        end
    elseif index == 9 then
        local center = x+w/2
        for channel = -3, 3 do
            local root, bend, mouth = center+channel*15, center+channel*72, center+channel*116
            c.line(root, y+122, bend, y+271, tint, 0.14, 2)
            c.line(bend, y+271, mouth, y+h-45, tint, 0.20, 2)
            c.line(bend+14, y+271, mouth+29, y+h-45, tint, 0.09)
        end
    elseif index == 10 then
        for ramp = 0, 5 do
            local py = y+99+ramp*68
            local west, east = x+58, x+w-58
            local top, bottom = py, py+32
            if ramp % 2 == 1 then top, bottom = bottom, top end
            c.line(west, top, east, bottom, tint, 0.18, 2)
            c.line(west, top+9, east, bottom+9, tint, 0.08)
            for pin = 0, 8 do
                c.dot(west+pin*(east-west)/8, top+pin*(bottom-top)/8, 2.5, tint, 0.24)
            end
        end
    elseif index == 11 then
        for chevron = -3, 3 do
            local anchor = x+w*0.5+chevron*100
            local offset = chevron < 0 and 107 or -107
            c.line(anchor, y+116, anchor+offset, y+259, tint, 0.18, 2)
            c.line(anchor+offset, y+259, anchor, y+402, tint, 0.18, 2)
            c.dot(anchor+offset, y+259, 4, tint, 0.20)
        end
    else
        local center, horizon = x+w/2, y+h-69
        for i = 1, 12 do
            local angle = math.pi*(i-0.5)/12
            local vx, vy = math.cos(angle), math.sin(angle)
            c.line(center+vx*112, horizon-vy*112, center+vx*282, horizon-vy*282, tint, 0.19, 2)
            c.dot(center+vx*297, horizon-vy*297, 3, tint, 0.28)
        end
        c.ring(center, horizon, 85, tint, 0.17, 2)
        c.line(x+28, horizon, x+w-28, horizon, tint, 0.22, 2)
    end
end

local function backdrop(c, w, h, scene, index)
    local px, py = BOARD_X, BOARD_Y
    local t = scene[3]
    c.gradient(px, py, px+w, py+h, scene[1], scene[2])
    for i = 1, 7 do
        local y = py+58+i*58
        c.line(px+15, y, px+w-15, y, t, 0.055)
    end
    for i = 1, 10 do
        local x = px+17+i*66
        c.line(x, py+74, x, py+h-28, t, 0.045)
    end

    local centerX, centerY = px+w*(index % 2 == 0 and 0.57 or 0.43), py+h*0.55
    for i = 1, 5 do
        c.ring(centerX, centerY, i*42, t, i == 4 and 0.20 or 0.11)
    end
    c.ring(centerX, centerY, 167, t, 0.11)
    for i = 0, 23 do
        local a = i*math.pi/12
        local vx, vy = math.cos(a), math.sin(a)
        c.line(centerX+vx*172, centerY+vy*172, centerX+vx*179, centerY+vy*179, t, 0.22)
    end
    for i = 1, 41 do
        local x = px+18+((i*71+index*29) % (w-36))
        local y = py+65+((i*137+index*13) % (h-102))
        c.dot(x, y, i % 7 == 0 and 1.75 or 0.9, t, i % 7 == 0 and 0.37 or 0.19)
    end
    sceneDetail(c, px, py, w, h, t, index)

    c.rect(px, py, px+w, py+64, color.dark, 0.30)
    c.rect(px, py+h-37, px+w, py+h, color.dark, 0.44)
    c.line(px+8, py+h-37, px+w-8, py+h-37, t, 0.26)
    c.rect(px, py, px+6, py+h, color.dark, 0.85)
    c.rect(px+w-6, py, px+w, py+h, color.dark, 0.85)
    c.edge(px, py, px+w, py+h, t, 0.52)
    for _, x in ipairs({px+14, px+w-14}) do
        c.ring(x, py+14, 3, t, 0.5)
        c.ring(x, py+h-13, 3, t, 0.5)
    end
end

local function gem(c, x, y, radius, kind, hit)
    local t = gems[kind]
    if hit then c.dot(x, y, radius+8, t[2], 0.16) end
    c.dot(x, y+2, radius+1, color.dark, 0.9)
    c.dot(x, y, radius+0.5, hit and t[2] or t[3])
    c.dot(x, y-0.65, radius-1.45, hit and t[1] or t[3])
    c.dot(x, y-1.5, radius-2.4, t[1], hit and 0.93 or 0.87)
    c.ring(x, y, radius-0.2, t[2], hit and 0.95 or 0.77)
    c.dot(x-radius*0.26, y-radius*0.33, radius*0.23, t[2], 0.83)
    if kind == 'orange' then
        c.ring(x, y+0.4, radius*0.48, t[2], 0.74)
    elseif kind == 'green' then
        c.line(x-3, y+1, x+3, y+1, t[2], 0.9)
        c.line(x, y-2, x, y+4, t[2], 0.9)
    elseif kind == 'purple' then
        c.triangle(x, y-3, x+3, y+1, x, y+5, t[2])
        c.triangle(x, y-3, x-3, y+1, x, y+5, t[2])
    end
end

local function marble(c, x, y, radius, resonance)
    local light = resonance and gems.purple[2] or color.gold
    local rim = resonance and gems.purple[1] or color.goldDeep
    c.dot(x, y, radius+5, light, 0.16)
    c.dot(x, y, radius+1.5, rim)
    c.dot(x, y-0.5, radius, light)
    c.dot(x-1.5, y-1.8, radius*0.56, color.white, 0.91)
    c.dot(x-2.2, y-2.4, radius*0.23, color.white)
end

local function accents(c, effects, now)
    for _, fx in ipairs(effects) do
        local age = now-fx.time
        local progress = math.max(0, math.min(1, age/0.62))
        local opacity = 1-progress
        local x, y = BOARD_X+fx.x, BOARD_Y+fx.y
        local tint = gems[fx.kind] and gems[fx.kind][2] or color.gold
        c.ring(x, y, 10+progress*25, tint, opacity*0.64)
        for i = 1, 6 do
            local a = i*math.pi/3+fx.x*0.11
            local spread = 9+progress*(21+i*3)
            c.dot(x+math.cos(a)*spread, y+math.sin(a)*spread, 2.4-progress, tint, opacity*0.86)
        end
        if fx.points and fx.kind ~= 'blue' then
            c.label(x+9, y-22-progress*22, '+'..formatScore(fx.points), 15, tint, opacity)
        end
        if fx.kind == 'green' then
            c.label(x+9, y-40-progress*22, 'BOOST', 14, tint, opacity)
        end
    end
end

local function field(c, ui, state, index, now)
    local run = state.run
    local px, py = BOARD_X, BOARD_Y
    local scene = scenes[(index-1)%#scenes+1]
    if run.phase == 'ready' then
        c.position(px, py)
        local clicked = ui.InvisibleButton('##playfield', run.width*c.scale, run.height*c.scale)
        local hover = ui.IsItemHovered() or ui.IsItemActive()
        local mx, my = ui.GetMousePos()
        local ax, ay = (mx-c.x)/c.scale-px, (my-c.y)/c.scale-py
        local onField = hover and ax >= 0 and ax <= run.width and ay >= 0 and ay <= run.height
        local moved = ax ~= state.mouseX or ay ~= state.mouseY
        if onField and (moved or clicked) then run:aim(ax, ay) end
        state.mouseX, state.mouseY = ax, ay
        local fired = false
        if ui.IsWindowFocused() and not ui.GetIO().typing then
            ui.CaptureKeyboard()
            local keys = ui.Key
            local left, right = ui.IsKeyDown(keys.LeftArrow), ui.IsKeyDown(keys.RightArrow)
            if left or right then
                local direction = (right and 1 or 0)-(left and 1 or 0)
                run:setAngle(run.angle+direction*state.dt*1.22)
            end
            fired = ui.IsKeyPressed(keys.Space)
        end
        if (clicked and onField) or fired then state:launch() end
    end

    ui.PushClipRect(c.x+px*c.scale, c.y+py*c.scale,
        c.x+(px+run.width)*c.scale, c.y+(py+run.height)*c.scale, true)
    backdrop(c, run.width, run.height, scene, index)
    local tx, ty = px+run.launcherX, py+run.launcherY
    if run.phase == 'ready' then
        if state.guideAngle ~= run.angle then
            state.guide = run:preview()
            state.guideAngle = run.angle
        end
        for i, p in ipairs(state.guide) do
            local fade = 1-i/(#state.guide+2)
            c.dot(px+p.x, py+p.y, 1.85+fade*1.25, color.gold, 0.18+fade*0.69)
        end
    end
    for _, peg in ipairs(run.pegs) do
        if not peg.removed then gem(c, px+peg.x, py+peg.y, run.pegRadius, peg.kind, peg.hit) end
    end

    local angle = run.angle or 0
    local bx, by = tx+math.sin(angle)*23, ty+math.cos(angle)*23
    c.line(tx, ty, bx, by, color.dark, 0.93, 16)
    c.line(tx, ty, bx, by, color.goldDeep, 0.97, 12)
    c.line(tx, ty, bx, by, color.ink, 1, 7)
    c.dot(tx, ty, 17, color.dark, 0.96)
    c.ring(tx, ty, 14, color.goldDeep, 0.92, 2)
    if run.phase == 'ready' then marble(c, tx, ty, run.ballRadius) else c.dot(tx, ty, 7, color.panel) end

    local catcher = px+run:catcher()
    local bottom = py+run.catcherY
    local half = run.catcherWidth/2
    c.line(px+18, bottom, px+run.width-18, bottom, scene[3], 0.26, 2)
    c.rect(catcher-half, bottom, catcher+half, bottom+19, color.dark, 0.93, 7)
    c.edge(catcher-half, bottom, catcher+half, bottom+19, color.goldDeep, 0.94, 7, 2)
    c.line(catcher-half+7, bottom+4, catcher+half-7, bottom+4, color.gold, 0.97, 2)
    for offset = -36, 36, 12 do
        if math.abs(offset) < half-7 then
            c.line(catcher+offset, bottom+15, catcher+offset+4, bottom+10, scene[3], 0.57, 2)
        end
    end

    if run.ball then
        local resonance = run.charge > 0
        local tint = resonance and gems.purple[2] or color.gold
        for i, point in ipairs(state.trail) do
            c.dot(px+point.x, py+point.y, 2+i/#state.trail*3.8, tint, i/#state.trail*0.26)
        end
        marble(c, px+run.ball.x, py+run.ball.y, run.ballRadius, resonance)
    end
    accents(c, state.effects, now)
    ui.PopClipRect()

    if run.phase == 'won' or run.phase == 'lost' then
        c.rect(px+1, py+1, px+run.width-1, py+run.height-1, color.dark, 0.57)
        local x, y = px+run.width/2-181, py+run.height/2-79
        panel(c, x, y, 362, 158)
        local won = run.phase == 'won'
        local title = won and 'Board cleared' or (run.shots == 0 and 'Out of shots' or 'Run ended')
        c.label(x+24, y+22, title, 32, won and color.gold or color.text)
        c.label(x+25, y+70, formatScore(run.score)..' points', 19, color.muted)
        if c.button('replay', 'Play again', x+24, y+108, 120, 31, true) then state:restart() end
        if c.button('advance', 'Next board', x+155, y+108, 130, 31) then state:pickBoard(1) end
    end
end

local function sidebar(c, state, board, mode)
    local run = state.run
    local x = 802
    panel(c, x, 118, 278, 550)
    c.label(x+19, 136, board.name, 25)
    local rules = run.maxAngle < state.Game.maxAngle and ' / Classic aim' or ''
    c.label(x+20, 169, mode.name..(state.challenge and ' / Duel' or '')..rules, 15, color.gold)
    local busy = run.phase == 'flight'
    if c.button('prevBoard', '< Board', x+18, 196, 111, 31, false, busy) then state:pickBoard(-1) end
    if c.button('nextBoard', 'Board >', x+137, 196, 121, 31, false, busy) then state:pickBoard(1) end
    if c.button('mode', 'Change mode', x+18, 235, 144, 31, false, busy) then state:pickMode() end
    if c.button('restart', 'Reset', x+171, 235, 87, 31, false, busy) then state:restart() end
    c.line(x+18, 282, x+259, 282, color.edge)

    c.label(x+19, 296, 'SCORE', 13, color.muted)
    c.label(x+17, 315, formatScore(run.score), 42, color.gold)
    c.label(x+19, 368, 'Best  '..formatScore(state:record().score), 15, color.muted)
    c.label(x+19, 407, 'AMBER TARGETS', 13, color.muted)
    c.label(x+19, 427, run.remaining..' left', 24)
    local fraction = math.max(0, math.min(1, (run.initialTargets-run.remaining)/math.max(1, run.initialTargets)))
    c.rect(x+19, 461, x+259, 469, color.inset, 1, 4)
    if fraction > 0 then c.rect(x+19, 461, x+19+240*fraction, 469, color.goldDeep, 1, 4) end
    c.label(x+19, 492, 'SHOTS LEFT', 13, color.muted)
    c.label(x+190, 483, tostring(run.shots), 30, run.shots < 3 and color.red or color.text)
    for i = 1, math.min(19, math.max(run.shots, mode.shots)) do
        local px = x+23+(i-1)*12.5
        c.dot(px, 526, 3.8, i <= run.shots and color.gold or color.edge, 0.95)
    end
    c.line(x+18, 551, x+259, 551, color.edge)
    c.label(x+19, 568, 'COMBO', 13, color.muted)
    c.label(x+19, 586, 'x'..tostring(run.combo or 0), 27)
    c.label(x+138, 568, 'SHOT POINTS', 13, color.muted)
    c.label(x+138, 589, formatScore(run.phase == 'flight' and run.shotScore or run.lastShot), 22)
    local status, tint
    if run.charge > 0 then
        status = 'Resonance x2  /  '..run.charge..' left'
        tint = gems.purple[2]
    elseif state.notice and state.now < state.noticeUntil then
        status, tint = state.notice, color[state.noticeTone]
    end
    if status then
        c.rect(x+18, 621, x+260, 651, tint, 0.13, 5)
        c.dot(x+29, 636, 3, tint)
        c.label(x+39, 628, status, 15, tint)
    end
end

local function play(c, ui, state, now)
    local index = at(state.Game.boards, state.run.boardId)
    field(c, ui, state, index, now)
    local order, board = at(state.Game.boards, state.run.boardId)
    local _, mode = at(state.Game.modes, state.run.modeId)
    sidebar(c, state, board, mode)
    c.label(20, 691, 'Aim with the mouse and click to launch', 17)
    c.label(20, 715, 'Keyboard: Left / Right to aim, Space to launch', 14, color.muted)
    c.label(628, 691, 'Board '..order..' of '..#state.Game.boards, 15, color.muted)
    local catchTip = state.run.timedCatcher and 'Time your shot for the catch tray.' or 'Tray starts moving on launch.'
    c.label(802, 691, catchTip, 16, color.gold)
end

local function help(c, state)
    panel(c, 20, 118, 1060, 580)
    c.label(49, 145, 'How to play', 34)
    c.label(50, 199, 'Clear every amber target before your shots run out.', 21)
    c.label(50, 234, 'Aim over the board and click to shoot. The dotted line shows the initial path.', 17, color.muted)
    c.label(50, 261, 'You can also aim with Left and Right and launch with Space while the window is focused.', 17, color.muted)
    c.line(50, 305, 1049, 305, color.edge)

    local legend = {
        {'orange', 'Amber', 'Clear these to finish the board.'},
        {'blue', 'Blue', 'Chain rebounds off these for points.'},
        {'green', 'Green', 'Boosts the rebound off this peg.'},
        {'purple', 'Violet', 'Doubles up to three new hits this shot.'},
    }
    for i, entry in ipairs(legend) do
        local x = 50+(i-1)*250
        gem(c, x+10, 342, 10, entry[1], false)
        c.label(x+32, 328, entry[2], 22, gems[entry[1]][2])
        c.label(x+1, 371, entry[3], 14, color.muted)
    end
    c.line(50, 411, 1049, 411, color.edge)
    c.label(50, 437, 'Catch tray', 23, color.gold)
    c.label(50, 473, 'The tray sweeps while you aim. Time your launch to land in it and get that shot back.', 17, color.muted)
    c.label(50, 509, 'Modes', 23, color.gold)
    for i, mode in ipairs(state.Game.modes) do
        c.label(50+(i-1)*330, 545, mode.name..'  /  '..mode.shots..' shots', 18)
        c.label(50+(i-1)*330, 574, mode.description, 14, color.muted)
    end
    c.label(50, 646, 'Use /peggle to open or close the cabinet.', 16, color.muted)
end

local function input(c, ui, id, value, x, y, w, limit, readOnly)
    c.position(x, y)
    ui.SetNextItemWidth(w*c.scale)
    local flags = readOnly and (ui.InputTextFlags.ReadOnly + ui.InputTextFlags.AutoSelectAll) or 0
    return ui.InputText('##'..id, value, limit, flags)
end

local function scoreShare(c, ui, state)
    if not state.shareRecord then
        c.label(50, 600, 'Select a score to link it in chat.', 16, color.muted)
        return
    end

    local channels = state.ScoreChat.channels
    local _, channel = at(channels, state.shareChannel)
    c.rect(48, 577, 1048, 631, color.inset, 1, 7)
    input(c, ui, 'scoreMessage', state.shareMessage, 60, 590, 482, 193, true)
    c.position(567, 590)
    ui.SetNextItemWidth(135*c.scale)
    if ui.BeginCombo('##scoreChannel', channel.label) then
        for _, option in ipairs(channels) do
            if ui.Selectable(option.label, option.id == channel.id) then state.shareChannel = option.id end
        end
        ui.EndCombo()
    end
    if c.button('shareScore', 'Link score', 726, 586, 123, 32, true) then state:sendScore() end
    if state.shareStatus then
        c.label(863, 593, state.shareStatus, 14, state.shareIssue and color.red or color.green)
    else
        c.label(863, 593, 'Click text to copy', 14, color.muted)
    end
end

local function records(c, ui, state)
    panel(c, 20, 118, 1060, 580)
    c.label(49, 145, 'Local records', 34)
    c.label(50, 199, 'Best completed run for each board and mode.', 17, color.muted)
    c.line(550, 253, 550, 602, color.edge)
    local boards, modes = state.Game.boards, state.Game.modes
    local rows = math.ceil(#boards/2)
    for side = 0, 1 do
        local x = 48+side*514
        c.label(x+9, 265, 'BOARD', 14, color.muted)
        for col, mode in ipairs(modes) do
            c.label(x+167+(col-1)*108, 262, mode.name, 17, color.gold)
        end
        for row = 1, rows do
            local board = boards[side*rows+row]
            if not board then break end
            local y = 291+(row-1)*46
            c.rect(x, y, x+486, y+41, row % 2 == 0 and color.inset or color.panel, 0.82, 5)
            c.label(x+11, y+9, board.name, 18)
            for col, mode in ipairs(modes) do
                local entry = state:record(board.id, mode.id)
                local scoreX = x+167+(col-1)*108
                local value = entry.score and formatScore(entry.score) or '-'
                if entry.score then
                    c.position(scoreX-14, y+3)
                    if ui.InvisibleButton('##record_'..board.id..'_'..mode.id, 98*c.scale, 34*c.scale,
                        ui.ButtonFlags.EnableNav) then
                        state:selectScore(board, mode, entry.score)
                    end
                    local selected = state.shareBoardId == board.id and state.shareModeId == mode.id
                    if selected or ui.IsItemHovered() or ui.IsItemFocused() then
                        c.rect(scoreX-14, y+3, scoreX+84, y+37, color.gold, selected and 0.18 or 0.095, 4)
                    end
                end
                if entry.cleared then c.dot(scoreX-9, y+19, 3, color.green) end
                c.label(scoreX, y+10, value, 17, entry.cleared and color.green or color.text)
            end
        end
    end
    scoreShare(c, ui, state)
    c.label(50, 644, 'Best combo  x'..tostring(state.profile.bestCombo), 17, color.gold)
    c.label(300, 644, 'Runs finished  '..tostring(state.profile.runs), 17, color.muted)
    c.dot(575, 652, 3, color.green)
    c.label(585, 644, 'Board cleared', 17, color.muted)
end

local function duelPage(c, ui, state)
    local duel, run = state.duel, state.run
    panel(c, 20, 118, 1060, 580)
    c.label(49, 145, 'Friend duels', 34)
    c.label(50, 194, 'Take turns on the same board and seed. Higher score wins.', 18, color.muted)
    c.line(50, 231, 1050, 231, color.edge)
    c.line(551, 249, 551, 644, color.edge)
    c.label(50, 253, 'Send a challenge', 24, color.gold)
    c.label(50, 292, 'Create a fresh match and share the code with a friend.', 16, color.muted)
    local finished = run.phase == 'won' or run.phase == 'lost'
    if c.button('createDuel', 'Create challenge', 50, 325, 158, 32, true, run.phase == 'flight') then
        state:createChallenge()
    end
    if c.button('shareResult', 'Get result code', 220, 325, 151, 32, false, not finished) then
        state:shareResult()
    end
    c.label(50, 381, 'Share code  /  Click then Ctrl+C', 16)
    input(c, ui, 'outCode', state.outCode, 50, 408, 467, 321, true)
    c.label(50, 452, 'Send by in-game tell', 16)
    state.peer = input(c, ui, 'friend', state.peer, 50, 479, 277, 65, false)
    if state.peer == '' then c.label(57, 481, 'Character name', 14, color.muted) end
    if c.button('sendCode', 'Send tell', 352, 471, 114, 32, false, state.outCode == '' or state.peer == '') then
        state:sendCode()
    end
    if c.button('listen', duel.listening and 'Tells on' or 'Tells off', 50, 530, 107, 31, duel.listening) then
        state:setListening(not duel.listening)
    end
    c.label(177, 537, 'Receive Peggle codes from in-game tells', 15, color.muted)
    if duel.inbox then
        c.label(50, 584, 'From '..duel.inbox.peer, 16, color.green)
        if c.button('inbox', 'Use received code', 50, 610, 176, 31) then
            state.inCode = duel.inbox.code
            state:importCode()
        end
    end

    c.label(580, 253, 'Join or compare', 24, color.gold)
    c.label(580, 292, 'Paste a challenge or result code from a friend.', 16, color.muted)
    state.inCode = input(c, ui, 'inCode', state.inCode, 580, 331, 468, 321, false)
    if c.button('readCode', 'Read code', 580, 370, 107, 32, true, state.inCode == '') then state:importCode() end
    if state.offer and c.button('acceptDuel', 'Play challenge', 698, 370, 151, 32, false, run.phase == 'flight') then
        state:acceptChallenge()
    end
    if state.offer then
        local _, board = at(state.Game.boards, state.offer.boardId)
        local _, mode = at(state.Game.modes, state.offer.modeId)
        local rules = state.offer.maxAngle < state.Game.maxAngle and '  /  Classic aim' or ''
        c.label(580, 424, board.name..'  /  '..mode.name..rules, 19)
        if not state.offer.timedCatcher then
            c.label(580, 448, 'Catch tray starts moving on launch.', 14, color.muted)
        end
    end
    if duel.verifying then
        c.label(580, 471, 'Replaying the submitted shots...', 17, color.gold)
    elseif duel.verified then
        local other = duel.verified
        c.label(580, 471, 'Friend score  '..formatScore(other.score), 21, color.green)
        if finished and run.boardId == other.boardId and run.seed == other.seed and
            run.modeId == other.modeId and run.maxAngle == other.maxAngle and run.timedCatcher == other.timedCatcher then
            local verdict = run.score == other.score and 'Tie' or (run.score > other.score and 'You win' or 'Friend wins')
            c.label(580, 509, 'Your score  '..formatScore(run.score)..'  /  '..verdict, 21)
        else
            if c.button('matchBoard', 'Play this seed', 580, 510, 150, 32, false, run.phase == 'flight') then
                state:beginChallenge(other.boardId, other.seed, other.modeId, other.maxAngle, other.timedCatcher)
            end
        end
    end
    c.line(50, 648, 1050, 648, color.edge)
    if duel.error or state.duelStatus then
        c.label(50, 661, duel.error or state.duelStatus, 15, (duel.error or state.duelIssue) and color.red or color.green)
    end
end

function Cabinet.draw(ui, state, now)
    local io = ui.GetIO()
    local initialScale = math.max(0.32, math.min(0.91, (io.width-28)/WIDTH, (io.height-36)/(HEIGHT+28)))
    local minW, minH = math.min(io.width, 470), math.min(io.height, 340)
    local initialW = math.min(io.width, math.max(minW, WIDTH*initialScale))
    local initialH = math.min(io.height, math.max(minH, HEIGHT*initialScale+24))
    ui.SetNextWindowSize(initialW, initialH, ui.Cond.FirstUseEver)
    ui.SetNextWindowPos((io.width-initialW)/2, (io.height-initialH)/2, ui.Cond.FirstUseEver)
    if ui.SetNextWindowSizeConstraints then ui.SetNextWindowSizeConstraints(minW, minH, io.width, io.height) end
    ui.PushStyleVar(ui.StyleVar.WindowPadding, 0, 0)
    ui.PushStyleVar(ui.StyleVar.WindowRounding, 8)
    ui.PushStyleColor(ui.Col.WindowBg, color.ink[1], color.ink[2], color.ink[3], 1)
    ui.PushStyleColor(ui.Col.TitleBg, color.inset[1], color.inset[2], color.inset[3], 1)
    ui.PushStyleColor(ui.Col.TitleBgActive, color.panel[1], color.panel[2], color.panel[3], 1)
    ui.PushStyleColor(ui.Col.FrameBg, color.inset[1], color.inset[2], color.inset[3], 1)
    ui.PushStyleColor(ui.Col.FrameBgHovered, color.edge[1], color.edge[2], color.edge[3], 1)
    ui.PushStyleColor(ui.Col.Text, color.text[1], color.text[2], color.text[3], 1)
    local flags = ui.WindowFlags.NoScrollbar + ui.WindowFlags.NoScrollWithMouse + ui.WindowFlags.NoCollapse
    local open, visible = ui.Begin('Peggle###PegworksCabinet', state.open, flags)
    state.open = open
    if visible then
        local x, y = ui.GetCursorScreenPos()
        local width, height = ui.GetContentRegionAvail()
        local scale = math.max(0.1, math.min(width/WIDTH, height/HEIGHT))
        local c = canvas(ui, x+(width-WIDTH*scale)/2, y+(height-HEIGHT*scale)/2, scale)
        header(c, state)
        if state.page == 'play' then play(c, ui, state, now)
        elseif state.page == 'duel' then duelPage(c, ui, state)
        elseif state.page == 'records' then records(c, ui, state)
        else help(c, state) end
        c.position(0, HEIGHT-1)
        ui.Dummy(WIDTH*scale, scale)
    end
    ui.End()
    ui.PopStyleColor(6)
    ui.PopStyleVar(2)
end

return Cabinet
