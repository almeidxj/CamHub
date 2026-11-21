--[[
    CamHub
    XENO FREECAM STUDIO v6.4  |  HUD v3 (Glass)
    Freecam cinematográfica + spectate + path + posições salvas + efeitos

    NOVIDADES v6.4
    - Adicionado controle visível de VELOCIDADE DO PERSONAGEM na aba CÂMERA.
    - Slider de 0 a 100 com valor numérico e preferência salva entre execuções.
    - Velocidade reaplicada após renascer e restaurada ao fechar/reexecutar.

    NOVIDADES v6.3
    - Corrigido: mouse travado no centro da tela (como shiftlock) depois de teleportar.

    NOVIDADES v6.2
    - Corrigido: a HUD do jogo voltava a aparecer depois de respawnar com a freecam ligada.
    - Corrigido: ao desligar a freecam depois de respawnar, a câmera não voltava pro boneco novo.
    - Botão de fechar agora fica no lado DIREITO e o de minimizar no lado ESQUERDO.

    CONTROLES (com a freecam ativa)
    W/A/S/D ......... mover            Q / E ........... descer / subir
    SHIFT ........... câmera lenta     ESPAÇO .......... câmera rápida
    RMB (segurar) ... olhar            SCROLL .......... zoom (FOV)
    CTRL+SCROLL ..... velocidade base  Z / C ........... inclinar câmera
    T ............... teleportar boneco pra câmera
    G ............... câmera volta pro boneco
    H ............... esconder meu boneco (só no meu client)
    R ............... resetar FOV e inclinação
    1-5 ............. ir pra posição salva   CTRL+1-5 ... salvar posição
    V ............... spectate (liga/desliga)   [ e ] ..... player anterior/próximo
    K / L ........... adicionar ponto / tocar path cinematográfico
    X ............... parar spectate/path

    SEMPRE
    P ............... ligar/desligar freecam
    RightShift ...... esconder/mostrar o menu

    HUD v3: visual "glass" com gradientes, borda animada e cantos redondos.
    Aba CONFIG com idioma e 6 temas (vermelho, monocromático, neon, vidro, oceano, floresta).
    Aba EFEITOS: controles de efeitos visuais da câmera.
    Idioma, tema, posição do menu, velocidades da câmera/personagem, sensibilidade, posições salvas
    (1-5) e pontos do path ficam salvos se você executar o script de novo.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local env = (type(getgenv) == "function" and getgenv()) or _G

-- LIMPA EXECUÇÃO ANTERIOR
if type(env.CAMHUB_FREECAM_CLEANUP) == "function" then
    pcall(env.CAMHUB_FREECAM_CLEANUP)
end

---------------------------------------------------------------------
-- CONFIGURAÇÃO
---------------------------------------------------------------------
local DEFAULT_BASE_SPEED = 30
local SLOW_MULT = 0.25          -- SHIFT
local FAST_MULT = 3.5           -- ESPAÇO

local ACCELERATION = 4.5
local DECELERATION = 5.5
local DEFAULT_ROTATION_SMOOTH = 9
local ZOOM_SMOOTH = 8

local DEFAULT_SENSITIVITY = 0.002
local ZOOM_STEP = 3

local MIN_FOV = 20
local MAX_FOV = 90

local MAX_ROLL_DEG = 45
local ROLL_SPEED_DEG = 40
local TRANSITION_TIME = 0.9

local SLOT_COUNT = 5

local TOGGLE_KEY = Enum.KeyCode.P
local HIDE_MENU_KEY = Enum.KeyCode.RightShift

local WIDTH = 364
local FULL_HEIGHT = 540
local HEADER_H = 48
local MINI_HEIGHT = HEADER_H
local DEFAULT_MENU_POS = { 25, 110 }

---------------------------------------------------------------------
