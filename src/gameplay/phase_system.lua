-- src/gameplay/phase_system.lua
-- Punto de entrada del sistema de fases desacoplado en módulos

local PhaseSystem = require 'src.gameplay.phase.core'

-- Cargar módulos que adjuntan funciones al PhaseSystem
require 'src.gameplay.phase.alignment'
require 'src.gameplay.phase.queries'
require 'src.gameplay.phase.boundaries'
require 'src.gameplay.phase.coordinates'
require 'src.gameplay.phase.expansion'

return PhaseSystem