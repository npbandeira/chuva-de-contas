-- Trilha instrumental gerada por código (sem depender de arquivo de música
-- e sem copiar nenhuma melodia existente): clima inspirado em plataforma
-- 16-bit animada (baixo saltitante "oom-pah" e arpejo rápido, como em Super
-- Mario World / Sonic) com uma batida simples e um sininho mágico no início
-- do loop, como aceno ao Magic Touch: Wizard for Hire.
local music = {}

local NOTE = {
    C3 = 130.81, E3 = 164.81, F3 = 174.61, G3 = 196.00, A3 = 220.00, B3 = 246.94,
    C4 = 261.63, D4 = 293.66, E4 = 329.63, F4 = 349.23, G4 = 392.00, A4 = 440.00,
    B4 = 493.88, C5 = 523.25, D5 = 587.33, E5 = 659.25, G5 = 783.99,
}

-- Progressão alegre e saltitante (I - vi - IV - V): baixo "oom-pah" grave/agudo
-- nos tempos fortes e arpejo correndo por cima, como nos temas de fase clássicos.
local CHORDS = {
    { bass = "C3", arp = { "C4", "E4", "G4", "C5", "G4", "E4" } },
    { bass = "A3", arp = { "A3", "C4", "E4", "A4", "E4", "C4" } },
    { bass = "F3", arp = { "F3", "A3", "C4", "F4", "C4", "A3" } },
    { bass = "G3", arp = { "G3", "B3", "D4", "G4", "D4", "B3" } },
}

local STEPS_PER_CHORD = 16 -- semicolcheias por acorde (um compasso 4/4)
local BPM = 172

local function buildSequence()
    local seq = {}
    for _, chord in ipairs(CHORDS) do
        local bassLow = NOTE[chord.bass]
        local bassHigh = bassLow * 2
        for step = 1, STEPS_PER_CHORD do
            -- baixo salta entre grave (tempo forte) e agudo (contratempo)
            local beat = (step - 1) % 4
            local bassFreq = (beat == 0 and bassLow) or (beat == 2 and bassHigh) or nil
            local arpNote = chord.arp[((step - 1) % #chord.arp) + 1]
            table.insert(seq, {
                bass = bassFreq,
                lead = NOTE[arpNote],
                kick = (step == 1 or step == 9),
                hat = (step % 2 == 1),
            })
        end
    end
    return seq
end

local function square(freq, t)
    return (math.sin(2 * math.pi * freq * t) >= 0) and 1 or -1
end

local function build()
    local rate = 22050
    local stepDur = 60 / BPM / 4 -- semicolcheia
    local seq = buildSequence()
    local samplesPerStep = math.floor(rate * stepDur)
    local total = samplesPerStep * #seq
    local data = love.sound.newSoundData(total, rate, 16, 1)

    for i = 0, total - 1 do
        local t = i / rate
        local step = math.floor(i / samplesPerStep) + 1
        local note = seq[step] or seq[#seq]
        local tt = t % stepDur

        local env = math.min(1, tt / 0.004) * math.min(1, (stepDur - tt) / 0.015)
        local sample = square(note.lead, t) * 0.13 * env
        if note.bass then
            sample = sample + square(note.bass, t) * 0.24 * env
        end

        if note.kick and tt < 0.08 then
            local kickFreq = 150 - (tt / 0.08) * 110
            sample = sample + math.sin(2 * math.pi * kickFreq * tt) * 0.35 * (1 - tt / 0.08)
        end

        if note.hat and tt < 0.03 then
            sample = sample + (math.random() * 2 - 1) * 0.12 * (1 - tt / 0.03)
        end

        -- sininho mágico só na abertura de cada volta do loop
        if t < 0.4 then
            local decay = math.exp(-t * 9)
            sample = sample + (math.sin(2 * math.pi * 1046.5 * t) + 0.6 * math.sin(2 * math.pi * 1568 * t)) * 0.18 *
                decay
        end

        data:setSample(i, math.max(-1, math.min(1, sample)))
    end

    return love.audio.newSource(data, "static")
end

function music.play()
    if music.source then return end
    music.source = build()
    music.source:setLooping(true)
    music.source:setVolume(0.3)
    music.source:play()
end

function music.stop()
    if music.source then music.source:stop() end
end

function music.setVolume(v)
    if music.source then music.source:setVolume(v) end
end

return music
