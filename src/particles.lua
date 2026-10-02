-- Estilhaços quadradinhos que espirram ao estourar uma conta e caem com
-- gravidade. Cada cena guarda a própria lista e chama estas funções nela.
local particles = {}

local GRAVITY = 320

-- espalha `count` partículas a partir de (x, y) em todas as direções
function particles.burst(list, x, y, color, count, minSpeed, maxSpeed)
    for _ = 1, count or 16 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(minSpeed or 60, maxSpeed or 240)
        table.insert(list, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = color,
            size = math.random(3, 6),
            t = 0,
            life = 0.4 + math.random() * 0.35,
        })
    end
end

function particles.update(list, dt)
    for i = #list, 1, -1 do
        local particle = list[i]
        particle.t = particle.t + dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vy = particle.vy + GRAVITY * dt
        if particle.t >= particle.life then
            table.remove(list, i)
        end
    end
end

function particles.draw(list)
    for _, particle in ipairs(list) do
        local alpha = 1 - particle.t / particle.life
        love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        love.graphics.rectangle("fill", particle.x, particle.y, particle.size, particle.size)
    end
end

return particles
