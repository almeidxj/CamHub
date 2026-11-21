local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.CAMHUB_FREECAM_CLEANUP) == "function" then
pcall(env.CAMHUB_FREECAM_CLEANUP)
end
local DEFAULT_BASE_SPEED = 30
local SLOW_MULT = 0.25
local FAST_MULT = 3.5
local ACCELERATION = 4.5
local DECELERATION = 5.5
local ROTATION_SMOOTH = 9
local ZOOM_SMOOTH = 8
local SENSITIVITY = 0.002
local ZOOM_STEP = 3
local MIN_FOV = 20
local MAX_FOV = 90
local MAX_ROLL_DEG = 45
local ROLL_SPEED_DEG = 40
local TRANSITION_TIME = 0.9
local SLOT_COUNT = 5
local TOGGLE_KEY = Enum.KeyCode.P
local HIDE_MENU_KEY = Enum.KeyCode.RightShift
local WIDTH = 340
local FULL_HEIGHT = 470
local MINI_HEIGHT = 40
local active = false
local minimized = false
local lookHeld = false
local mode = "free"
local connections = {}
local position = Vector3.zero
local velocity = Vector3.zero
local yaw, pitch, roll = 0, 0, 0
local targetYaw, targetPitch, targetRoll = 0, 0, 0
local currentFOV, targetFOV = 70, 70
local baseSpeed = DEFAULT_BASE_SPEED
local currentSpeedMode = "NORMAL"
local currentSpeedValue = DEFAULT_BASE_SPEED
local camera
local oldCameraType
local oldCameraSubject
local oldFOV
local oldMouseBehavior
local oldMouseIconEnabled
local lastCF
local specTarget
local specMode = 1
local specDist = 12
local specFocus
local specFPCF
local orbitSpeed = 0.4
local keyframes = {}
local pathDuration = 8
local pathSmooth = true
local pathLoop = false
local pathT = 0
local pathProgress = 0
local trans
local slots = {}
local hideSelf = false
local hideTimer = 0
local shakeAmount = 0
local notifyText
local notifyToken = 0
local syncTimer = 0
local streamEnabled = true
local streamBusy = false
local streamLastPos
local streamLastTime = 0
local specLastPos
local STREAM_MOVE_DIST = 40
local STREAM_REFRESH = 2.5
local STREAM_TIMEOUT = 2
local STREAM_MIN_DIST = 100
local function streamTick()
if not streamEnabled or streamBusy then return end
if not workspace.StreamingEnabled then return end
local pos
if mode == "spectate" and specTarget then
local character = specTarget.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if root then
specLastPos = root.Position
end
pos = specLastPos
end
pos = pos or (lastCF and lastCF.Position)
if not pos then return end
local myCharacter = player.Character
local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
if myRoot and (myRoot.Position - pos).Magnitude < STREAM_MIN_DIST then
return
end
local now = os.clock()
if streamLastPos
and (pos - streamLastPos).Magnitude < STREAM_MOVE_DIST
and now - streamLastTime < STREAM_REFRESH then
return
end
streamBusy = true
streamLastPos = pos
streamLastTime = now
task.spawn(function()
pcall(function()
player:RequestStreamAroundAsync(pos, STREAM_TIMEOUT)
end)
streamBusy = false
streamLastTime = os.clock()
end)
end
local ui = {}
local setFreecam, teleportToCamera, cameraToCharacter
local saveSlot, gotoSlot
local startSpectate, exitSpectate, cycleSpectate, toggleSpectate
local addKeyframe, togglePath, clearPath, startPath
local refreshStatus, applyHideSelf, stopAutomation
local function angleDiff(from, to)
return math.atan2(math.sin(to - from), math.cos(to - from))
end
local function smoothAngle(current, target, alpha)
return current + angleDiff(current, target) * alpha
end
local function smoothstep(u)
return u * u * (3 - 2 * u)
end
local function catmull(p0, p1, p2, p3, t)
local t2 = t * t
local t3 = t2 * t
return 0.5 * (
(2 * p1)
+ (-p0 + p2) * t
+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3
)
end
local function anglesFromLook(look)
return math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
end
local function isDown(keyCode)
return UIS:IsKeyDown(keyCode)
end
local function ctrlDown()
return UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)
end
local function mk(className, props, parent)
local obj = Instance.new(className)
for key, value in pairs(props) do
obj[key] = value
end
obj.Parent = parent
return obj
end
local function round(obj, radius)
mk("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, obj)
end
local C = {}
local K = {
themeHooks = {},
langHooks = {},
speedKeys = { NORMAL = "sp_normal", ["RÁPIDO"] = "sp_fast", LENTO = "sp_slow" },
}
local activeSlider
K.themes = {
red = {
bg = Color3.fromRGB(9, 9, 12),
header = Color3.fromRGB(30, 8, 12),
panel = Color3.fromRGB(24, 24, 30),
line = Color3.fromRGB(72, 40, 46),
accent = Color3.fromRGB(225, 35, 50),
primary = Color3.fromRGB(150, 22, 36),
primaryText = Color3.fromRGB(255, 255, 255),
sel = Color3.fromRGB(190, 30, 46),
selText = Color3.fromRGB(255, 255, 255),
text = Color3.fromRGB(238, 238, 242),
sub = Color3.fromRGB(150, 150, 158),
good = Color3.fromRGB(75, 255, 125),
bad = Color3.fromRGB(235, 80, 80),
note = Color3.fromRGB(255, 200, 80),
track = Color3.fromRGB(40, 40, 50),
knobOn = Color3.fromRGB(255, 255, 255),
knobOff = Color3.fromRGB(175, 175, 182),
},
mono = {
bg = Color3.fromRGB(8, 8, 8),
header = Color3.fromRGB(26, 26, 26),
panel = Color3.fromRGB(26, 26, 26),
line = Color3.fromRGB(72, 72, 72),
accent = Color3.fromRGB(245, 245, 245),
primary = Color3.fromRGB(222, 222, 222),
primaryText = Color3.fromRGB(8, 8, 8),
sel = Color3.fromRGB(255, 255, 255),
selText = Color3.fromRGB(8, 8, 8),
text = Color3.fromRGB(240, 240, 240),
sub = Color3.fromRGB(150, 150, 150),
good = Color3.fromRGB(255, 255, 255),
bad = Color3.fromRGB(130, 130, 130),
note = Color3.fromRGB(210, 210, 210),
track = Color3.fromRGB(46, 46, 46),
knobOn = Color3.fromRGB(8, 8, 8),
knobOff = Color3.fromRGB(170, 170, 170),
},
}
K.langs = {
{ code = "pt", name = "Português (BR)" },
{ code = "en", name = "English" },
{ code = "ru", name = "Русский" },
{ code = "es", name = "Español" },
{ code = "fr", name = "Français" },
{ code = "de", name = "Deutsch" },
{ code = "zh", name = "中文" },
{ code = "ja", name = "日本語" },
}
K.str = {}
K.str.pt = {
tab_camera = "CÂMERA", tab_spect = "SPECT", tab_path = "PATH", tab_fx = "FX", tab_cfg = "CONFIG",
cam_on = "ATIVAR FREECAM  [P]", cam_off = "DESATIVAR FREECAM  [P]",
cam_tp = "TELEPORTAR BONECO PRA CÂMERA  [T]", cam_back = "CÂMERA VOLTA PRO BONECO  [G]",
sec_view = "VISÃO E MOVIMENTO", s_fov = "FOV", s_roll = "Inclinação (graus)",
s_speed = "Velocidade base", t_hide = "Esconder meu boneco [H]", t_stream = "Carregar mapa em volta da câmera",
cam_goto = "IR PARA POSIÇÃO SALVA (teclas 1-5)", cam_save = "SALVAR POSIÇÃO AQUI (CTRL + 1-5)",
sec_help = "CONTROLES",
cam_help = "WASD mover | Q/E descer/subir | SHIFT lento | ESPAÇO rápido\nRMB olhar | SCROLL zoom | CTRL+SCROLL velocidade | Z/C inclinar\nT teleporte | G câmera->boneco | H esconder boneco | R resetar\nV/[ ] spectate | K/L path | X parar | RShift esconde o menu",
sp_hint = "Clique num jogador, ou use V e [ ] na câmera.",
sp_follow = "SEGUIR", sp_orbit = "ORBITAR", sp_first = "1ª PESSOA",
sp_exit = "SAIR DO SPECTATE  [X]", s_dist = "Distância da câmera",
s_orbit = "Velocidade do orbitar", sp_players = "JOGADORES NO SERVIDOR",
path_add = "+ ADICIONAR PONTO AQUI  [K]", path_play = "TOCAR PATH  [L]", path_stop = "PARAR PATH  [L]",
path_info = "PONTOS: %d   |   DURAÇÃO: %.1fs", s_dur = "Duração total (s)",
t_smooth = "Suavizar início e fim", t_loop = "Repetir (volta pro início)",
path_clear = "LIMPAR PONTOS",
path_help = "Posicione a câmera, aperte K em cada ponto (mín. 2) e toque o path. A câmera passa por todos os pontos em curva suave, com FOV e inclinação também interpolados. Pra parar durante a reprodução, use L, X ou o botão.",
sec_effects = "EFEITOS DE TELA", s_bars = "Barras de cinema (%)", s_blur = "Blur",
s_bloom = "Bloom (brilho)", s_dof = "Desfoque de fundo (DOF)", s_focus = "Distância do foco",
s_shake = "Tremida de câmera", sec_color = "COR", s_bright = "Brilho", s_contrast = "Contraste",
s_sat = "Saturação", fx_presets = "PRESETS DE COR",
p_normal = "NORMAL", p_cinema = "CINEMA", p_bw = "P&B", p_cold = "FRIO", p_warm = "QUENTE",
fx_reset = "RESETAR TODOS OS EFEITOS",
cfg_lang = "IDIOMA", cfg_theme = "TEMA", th_red = "VERMELHO / PRETO", th_mono = "PRETO / BRANCO",
cfg_reset = "RESTAURAR POSIÇÃO DO MENU", sec_about = "SOBRE",
st_off = "STATUS: OFF", st_spect = "SPECT: %s", st_dist = "DIST %.0f", st_path = "PATH %d%%",
st_trans = "TRANSIÇÃO", st_free = "ATIVO - LIVRE", st_vel = "VEL: %s %.0f",
sp_normal = "NORMAL", sp_fast = "RÁPIDO", sp_slow = "LENTO",
n_activate = "ATIVE A FREECAM", n_stoppath = "PARE O PATH ANTES", n_point = "PONTO #%d",
n_cleared = "PATH LIMPO", n_min2 = "MIN. 2 PONTOS", n_pathstop = "PATH PARADO",
n_saved = "SALVO NO SLOT %d", n_slotempty = "SLOT %d VAZIO", n_noplayers = "SEM OUTROS PLAYERS",
n_playerleft = "PLAYER SAIU", n_exitspect = "SAIA DO SPECTATE", n_nochar = "BONECO NÃO ENCONTRADO",
n_tp = "TELEPORTADO!", n_failed = "FALHOU",
}
K.str.en = {
tab_camera = "CAMERA", tab_spect = "SPECT", tab_path = "PATH", tab_fx = "FX", tab_cfg = "CONFIG",
cam_on = "ENABLE FREECAM  [P]", cam_off = "DISABLE FREECAM  [P]",
cam_tp = "TELEPORT CHARACTER TO CAMERA  [T]", cam_back = "CAMERA BACK TO CHARACTER  [G]",
sec_view = "VIEW & MOVEMENT", s_fov = "FOV", s_roll = "Tilt (degrees)",
s_speed = "Base speed", t_hide = "Hide my character [H]", t_stream = "Load map around the camera",
cam_goto = "GO TO SAVED POSITION (keys 1-5)", cam_save = "SAVE POSITION HERE (CTRL + 1-5)",
sec_help = "CONTROLS",
cam_help = "WASD move | Q/E down/up | SHIFT slow | SPACE fast\nRMB look | SCROLL zoom | CTRL+SCROLL speed | Z/C tilt\nT teleport | G camera->character | H hide character | R reset\nV/[ ] spectate | K/L path | X stop | RShift hides the menu",
sp_hint = "Click a player, or use V and [ ] while in the camera.",
sp_follow = "FOLLOW", sp_orbit = "ORBIT", sp_first = "1ST PERSON",
sp_exit = "EXIT SPECTATE  [X]", s_dist = "Camera distance",
s_orbit = "Orbit speed", sp_players = "PLAYERS IN SERVER",
path_add = "+ ADD POINT HERE  [K]", path_play = "PLAY PATH  [L]", path_stop = "STOP PATH  [L]",
path_info = "POINTS: %d   |   DURATION: %.1fs", s_dur = "Total duration (s)",
t_smooth = "Smooth start and end", t_loop = "Loop (back to start)",
path_clear = "CLEAR POINTS",
path_help = "Position the camera, press K at each point (min. 2) and play the path. The camera flies through every point on a smooth curve, with FOV and tilt interpolated too. To stop playback use L, X or the button.",
sec_effects = "SCREEN EFFECTS", s_bars = "Cinema bars (%)", s_blur = "Blur",
s_bloom = "Bloom (glow)", s_dof = "Background blur (DOF)", s_focus = "Focus distance",
s_shake = "Camera shake", sec_color = "COLOR", s_bright = "Brightness", s_contrast = "Contrast",
s_sat = "Saturation", fx_presets = "COLOR PRESETS",
p_normal = "NORMAL", p_cinema = "CINEMA", p_bw = "B&W", p_cold = "COLD", p_warm = "WARM",
fx_reset = "RESET ALL EFFECTS",
cfg_lang = "LANGUAGE", cfg_theme = "THEME", th_red = "RED / BLACK", th_mono = "BLACK / WHITE",
cfg_reset = "RESET MENU POSITION", sec_about = "ABOUT",
st_off = "STATUS: OFF", st_spect = "SPECT: %s", st_dist = "DIST %.0f", st_path = "PATH %d%%",
st_trans = "TRANSITION", st_free = "ACTIVE - FREE", st_vel = "SPD: %s %.0f",
sp_normal = "NORMAL", sp_fast = "FAST", sp_slow = "SLOW",
n_activate = "ENABLE THE FREECAM", n_stoppath = "STOP THE PATH FIRST", n_point = "POINT #%d",
n_cleared = "PATH CLEARED", n_min2 = "MIN. 2 POINTS", n_pathstop = "PATH STOPPED",
n_saved = "SAVED TO SLOT %d", n_slotempty = "SLOT %d EMPTY", n_noplayers = "NO OTHER PLAYERS",
n_playerleft = "PLAYER LEFT", n_exitspect = "EXIT SPECTATE FIRST", n_nochar = "CHARACTER NOT FOUND",
n_tp = "TELEPORTED!", n_failed = "FAILED",
}
K.str.ru = {
tab_camera = "КАМЕРА", tab_spect = "НАБЛ.", tab_path = "ПУТЬ", tab_fx = "FX", tab_cfg = "НАСТР.",
cam_on = "ВКЛЮЧИТЬ ФРИКАМ  [P]", cam_off = "ВЫКЛЮЧИТЬ ФРИКАМ  [P]",
cam_tp = "ТЕЛЕПОРТ ПЕРСОНАЖА К КАМЕРЕ  [T]", cam_back = "КАМЕРА К ПЕРСОНАЖУ  [G]",
sec_view = "ОБЗОР И ДВИЖЕНИЕ", s_fov = "Угол обзора (FOV)", s_roll = "Наклон (градусы)",
s_speed = "Базовая скорость", t_hide = "Скрыть моего персонажа [H]", t_stream = "Подгружать карту вокруг камеры",
cam_goto = "К СОХРАНЁННОЙ ПОЗИЦИИ (клавиши 1-5)", cam_save = "СОХРАНИТЬ ПОЗИЦИЮ (CTRL + 1-5)",
sec_help = "УПРАВЛЕНИЕ",
cam_help = "WASD движение | Q/E вниз/вверх | SHIFT медленно | ПРОБЕЛ быстро\nПКМ осмотр | КОЛЕСО зум | CTRL+КОЛЕСО скорость | Z/C наклон\nT телепорт | G камера->персонаж | H скрыть персонажа | R сброс\nV/[ ] наблюдение | K/L путь | X стоп | RShift скрыть/показать меню",
sp_hint = "Нажмите на игрока или используйте V и [ ] в режиме камеры.",
sp_follow = "СЛЕДОВАТЬ", sp_orbit = "ОРБИТА", sp_first = "ОТ 1-ГО ЛИЦА",
sp_exit = "ВЫЙТИ ИЗ НАБЛЮДЕНИЯ  [X]", s_dist = "Дистанция камеры",
s_orbit = "Скорость орбиты", sp_players = "ИГРОКИ НА СЕРВЕРЕ",
path_add = "+ ДОБАВИТЬ ТОЧКУ  [K]", path_play = "ЗАПУСТИТЬ ПУТЬ  [L]", path_stop = "ОСТАНОВИТЬ ПУТЬ  [L]",
path_info = "ТОЧЕК: %d   |   ВРЕМЯ: %.1f с", s_dur = "Общая длительность (с)",
t_smooth = "Плавный старт и финиш", t_loop = "Повторять (с начала)",
path_clear = "ОЧИСТИТЬ ТОЧКИ",
path_help = "Расположите камеру, нажмите K в каждой точке (минимум 2) и запустите путь. Камера плавно пройдёт через все точки, а FOV и наклон тоже интерполируются. Чтобы остановить, нажмите L, X или кнопку.",
sec_effects = "ЭФФЕКТЫ ЭКРАНА", s_bars = "Кино-полосы (%)", s_blur = "Размытие",
s_bloom = "Свечение (Bloom)", s_dof = "Размытие фона (DOF)", s_focus = "Дистанция фокуса",
s_shake = "Тряска камеры", sec_color = "ЦВЕТ", s_bright = "Яркость", s_contrast = "Контраст",
s_sat = "Насыщенность", fx_presets = "ЦВЕТОВЫЕ ПРЕСЕТЫ",
p_normal = "ОБЫЧНЫЙ", p_cinema = "КИНО", p_bw = "Ч/Б", p_cold = "ХОЛОД.", p_warm = "ТЁПЛЫЙ",
fx_reset = "СБРОСИТЬ ВСЕ ЭФФЕКТЫ",
cfg_lang = "ЯЗЫК", cfg_theme = "ТЕМА", th_red = "КРАСНЫЙ / ЧЁРНЫЙ", th_mono = "ЧЁРНЫЙ / БЕЛЫЙ",
cfg_reset = "СБРОСИТЬ ПОЗИЦИЮ МЕНЮ", sec_about = "О ПРОГРАММЕ",
st_off = "СТАТУС: ВЫКЛ", st_spect = "НАБЛЮД.: %s", st_dist = "ДИСТ %.0f", st_path = "ПУТЬ %d%%",
st_trans = "ПЕРЕХОД", st_free = "АКТИВНО - СВОБОДНО", st_vel = "СКОР: %s %.0f",
sp_normal = "НОРМ", sp_fast = "БЫСТРО", sp_slow = "МЕДЛЕННО",
n_activate = "СНАЧАЛА ВКЛЮЧИТЕ ФРИКАМ", n_stoppath = "СНАЧАЛА ОСТАНОВИТЕ ПУТЬ", n_point = "ТОЧКА #%d",
n_cleared = "ПУТЬ ОЧИЩЕН", n_min2 = "МИНИМУМ 2 ТОЧКИ", n_pathstop = "ПУТЬ ОСТАНОВЛЕН",
n_saved = "СОХРАНЕНО В СЛОТ %d", n_slotempty = "СЛОТ %d ПУСТ", n_noplayers = "НЕТ ДРУГИХ ИГРОКОВ",
n_playerleft = "ИГРОК ВЫШЕЛ", n_exitspect = "СНАЧАЛА ВЫЙДИТЕ ИЗ НАБЛЮДЕНИЯ", n_nochar = "ПЕРСОНАЖ НЕ НАЙДЕН",
n_tp = "ТЕЛЕПОРТИРОВАН!", n_failed = "ОШИБКА",
}
K.str.es = {
tab_camera = "CÁMARA", tab_spect = "SPECT", tab_path = "RUTA", tab_fx = "FX", tab_cfg = "CONFIG",
cam_on = "ACTIVAR FREECAM  [P]", cam_off = "DESACTIVAR FREECAM  [P]",
cam_tp = "TELEPORTAR PERSONAJE A LA CÁMARA  [T]", cam_back = "CÁMARA VUELVE AL PERSONAJE  [G]",
sec_view = "VISTA Y MOVIMIENTO", s_fov = "FOV", s_roll = "Inclinación (grados)",
s_speed = "Velocidad base", t_hide = "Ocultar mi personaje [H]", t_stream = "Cargar mapa alrededor de la cámara",
cam_goto = "IR A POSICIÓN GUARDADA (teclas 1-5)", cam_save = "GUARDAR POSICIÓN AQUÍ (CTRL + 1-5)",
sec_help = "CONTROLES",
cam_help = "WASD mover | Q/E bajar/subir | SHIFT lento | ESPACIO rápido\nClic der. mirar | RUEDA zoom | CTRL+RUEDA velocidad | Z/C inclinar\nT teletransporte | G cámara->personaje | H ocultar personaje | R reiniciar\nV/[ ] espectear | K/L ruta | X parar | RShift oculta el menú",
sp_hint = "Haz clic en un jugador, o usa V y [ ] en la cámara.",
sp_follow = "SEGUIR", sp_orbit = "ORBITAR", sp_first = "1ª PERSONA",
sp_exit = "SALIR DE ESPECTEAR  [X]", s_dist = "Distancia de la cámara",
s_orbit = "Velocidad de órbita", sp_players = "JUGADORES EN EL SERVIDOR",
path_add = "+ AÑADIR PUNTO AQUÍ  [K]", path_play = "REPRODUCIR RUTA  [L]", path_stop = "DETENER RUTA  [L]",
path_info = "PUNTOS: %d   |   DURACIÓN: %.1fs", s_dur = "Duración total (s)",
t_smooth = "Suavizar inicio y final", t_loop = "Repetir (vuelve al inicio)",
path_clear = "BORRAR PUNTOS",
path_help = "Coloca la cámara, pulsa K en cada punto (mín. 2) y reproduce la ruta. La cámara pasa por todos los puntos en una curva suave, con FOV e inclinación también interpolados. Para detenerla usa L, X o el botón.",
sec_effects = "EFECTOS DE PANTALLA", s_bars = "Barras de cine (%)", s_blur = "Desenfoque",
s_bloom = "Bloom (brillo)", s_dof = "Desenfoque de fondo (DOF)", s_focus = "Distancia de enfoque",
s_shake = "Temblor de cámara", sec_color = "COLOR", s_bright = "Brillo", s_contrast = "Contraste",
s_sat = "Saturación", fx_presets = "PRESETS DE COLOR",
p_normal = "NORMAL", p_cinema = "CINE", p_bw = "B/N", p_cold = "FRÍO", p_warm = "CÁLIDO",
fx_reset = "RESTABLECER EFECTOS",
cfg_lang = "IDIOMA", cfg_theme = "TEMA", th_red = "ROJO / NEGRO", th_mono = "NEGRO / BLANCO",
cfg_reset = "RESTAURAR POSICIÓN DEL MENÚ", sec_about = "ACERCA DE",
st_off = "ESTADO: OFF", st_spect = "ESPEC: %s", st_dist = "DIST %.0f", st_path = "RUTA %d%%",
st_trans = "TRANSICIÓN", st_free = "ACTIVO - LIBRE", st_vel = "VEL: %s %.0f",
sp_normal = "NORMAL", sp_fast = "RÁPIDO", sp_slow = "LENTO",
n_activate = "ACTIVA LA FREECAM", n_stoppath = "DETÉN LA RUTA ANTES", n_point = "PUNTO #%d",
n_cleared = "RUTA BORRADA", n_min2 = "MÍN. 2 PUNTOS", n_pathstop = "RUTA DETENIDA",
n_saved = "GUARDADO EN SLOT %d", n_slotempty = "SLOT %d VACÍO", n_noplayers = "NO HAY OTROS JUGADORES",
n_playerleft = "EL JUGADOR SALIÓ", n_exitspect = "SAL DEL MODO ESPECTEAR", n_nochar = "PERSONAJE NO ENCONTRADO",
n_tp = "¡TELETRANSPORTADO!", n_failed = "FALLÓ",
}
K.str.fr = {
tab_camera = "CAMÉRA", tab_spect = "SPECT", tab_path = "TRAJET", tab_fx = "FX", tab_cfg = "CONFIG",
cam_on = "ACTIVER LA FREECAM  [P]", cam_off = "DÉSACTIVER LA FREECAM  [P]",
cam_tp = "TÉLÉPORTER LE PERSO À LA CAMÉRA  [T]", cam_back = "CAMÉRA VERS LE PERSO  [G]",
sec_view = "VUE ET MOUVEMENT", s_fov = "FOV", s_roll = "Inclinaison (degrés)",
s_speed = "Vitesse de base", t_hide = "Cacher mon personnage [H]", t_stream = "Charger la carte autour de la caméra",
cam_goto = "ALLER À UNE POSITION SAUVEGARDÉE (touches 1-5)", cam_save = "SAUVEGARDER LA POSITION (CTRL + 1-5)",
sec_help = "COMMANDES",
cam_help = "WASD bouger | Q/E descendre/monter | SHIFT lent | ESPACE rapide\nClic droit regarder | MOLETTE zoom | CTRL+MOLETTE vitesse | Z/C incliner\nT téléporter | G caméra->perso | H cacher perso | R réinitialiser\nV/[ ] spectateur | K/L trajet | X arrêter | RShift masque le menu",
sp_hint = "Cliquez sur un joueur, ou utilisez V et [ ] avec la caméra.",
sp_follow = "SUIVRE", sp_orbit = "ORBITER", sp_first = "1RE PERSONNE",
sp_exit = "QUITTER LE MODE SPECT  [X]", s_dist = "Distance de la caméra",
s_orbit = "Vitesse d'orbite", sp_players = "JOUEURS SUR LE SERVEUR",
path_add = "+ AJOUTER UN POINT ICI  [K]", path_play = "LANCER LE TRAJET  [L]", path_stop = "ARRÊTER LE TRAJET  [L]",
path_info = "POINTS : %d   |   DURÉE : %.1fs", s_dur = "Durée totale (s)",
t_smooth = "Adoucir début et fin", t_loop = "Répéter (retour au début)",
path_clear = "EFFACER LES POINTS",
path_help = "Placez la caméra, appuyez sur K à chaque point (min. 2) puis lancez le trajet. La caméra passe par tous les points en courbe douce, avec FOV et inclinaison interpolés. Pour arrêter, utilisez L, X ou le bouton.",
sec_effects = "EFFETS D'ÉCRAN", s_bars = "Bandes cinéma (%)", s_blur = "Flou",
s_bloom = "Bloom (éclat)", s_dof = "Flou d'arrière-plan (DOF)", s_focus = "Distance de mise au point",
s_shake = "Tremblement caméra", sec_color = "COULEUR", s_bright = "Luminosité", s_contrast = "Contraste",
s_sat = "Saturation", fx_presets = "PRÉRÉGLAGES COULEUR",
p_normal = "NORMAL", p_cinema = "CINÉMA", p_bw = "N&B", p_cold = "FROID", p_warm = "CHAUD",
fx_reset = "RÉINITIALISER LES EFFETS",
cfg_lang = "LANGUE", cfg_theme = "THÈME", th_red = "ROUGE / NOIR", th_mono = "NOIR / BLANC",
cfg_reset = "RÉINITIALISER LA POSITION DU MENU", sec_about = "À PROPOS",
st_off = "STATUT : OFF", st_spect = "SPECT : %s", st_dist = "DIST %.0f", st_path = "TRAJET %d%%",
st_trans = "TRANSITION", st_free = "ACTIF - LIBRE", st_vel = "VIT : %s %.0f",
sp_normal = "NORMAL", sp_fast = "RAPIDE", sp_slow = "LENT",
n_activate = "ACTIVEZ LA FREECAM", n_stoppath = "ARRÊTEZ D'ABORD LE TRAJET", n_point = "POINT #%d",
n_cleared = "TRAJET EFFACÉ", n_min2 = "MIN. 2 POINTS", n_pathstop = "TRAJET ARRÊTÉ",
n_saved = "SAUVÉ DANS LE SLOT %d", n_slotempty = "SLOT %d VIDE", n_noplayers = "AUCUN AUTRE JOUEUR",
n_playerleft = "LE JOUEUR EST PARTI", n_exitspect = "QUITTEZ LE MODE SPECT", n_nochar = "PERSO INTROUVABLE",
n_tp = "TÉLÉPORTÉ !", n_failed = "ÉCHEC",
}
K.str.de = {
tab_camera = "KAMERA", tab_spect = "SPEKT.", tab_path = "PFAD", tab_fx = "FX", tab_cfg = "CONFIG",
cam_on = "FREECAM AKTIVIEREN  [P]", cam_off = "FREECAM DEAKTIVIEREN  [P]",
cam_tp = "FIGUR ZUR KAMERA TELEPORTIEREN  [T]", cam_back = "KAMERA ZURÜCK ZUR FIGUR  [G]",
sec_view = "SICHT & BEWEGUNG", s_fov = "FOV", s_roll = "Neigung (Grad)",
s_speed = "Grundgeschwindigkeit", t_hide = "Meine Figur verstecken [H]", t_stream = "Karte um die Kamera laden",
cam_goto = "ZU GESPEICHERTER POSITION (Tasten 1-5)", cam_save = "POSITION HIER SPEICHERN (STRG + 1-5)",
sec_help = "STEUERUNG",
cam_help = "WASD bewegen | Q/E runter/hoch | SHIFT langsam | LEERTASTE schnell\nRMT umsehen | MAUSRAD Zoom | STRG+MAUSRAD Tempo | Z/C neigen\nT teleportieren | G Kamera->Figur | H Figur verstecken | R zurücksetzen\nV/[ ] zuschauen | K/L Pfad | X stoppen | RShift blendet Menü aus/ein",
sp_hint = "Klicke auf einen Spieler oder nutze V und [ ] in der Kamera.",
sp_follow = "FOLGEN", sp_orbit = "UMKREISEN", sp_first = "ICH-PERSPEKTIVE",
sp_exit = "ZUSCHAUEN BEENDEN  [X]", s_dist = "Kameraabstand",
s_orbit = "Umkreisgeschwindigkeit", sp_players = "SPIELER AUF DEM SERVER",
path_add = "+ PUNKT HIER HINZUFÜGEN  [K]", path_play = "PFAD ABSPIELEN  [L]", path_stop = "PFAD STOPPEN  [L]",
path_info = "PUNKTE: %d   |   DAUER: %.1fs", s_dur = "Gesamtdauer (s)",
t_smooth = "Start und Ende glätten", t_loop = "Wiederholen (zurück zum Start)",
path_clear = "PUNKTE LÖSCHEN",
path_help = "Positioniere die Kamera, drücke an jedem Punkt K (min. 2) und spiele den Pfad ab. Die Kamera fliegt in einer weichen Kurve durch alle Punkte; FOV und Neigung werden ebenfalls interpoliert. Zum Stoppen nutze L, X oder den Button.",
sec_effects = "BILDSCHIRMEFFEKTE", s_bars = "Kinobalken (%)", s_blur = "Unschärfe",
s_bloom = "Bloom (Glanz)", s_dof = "Hintergrundunschärfe (DOF)", s_focus = "Fokusabstand",
s_shake = "Kamerawackeln", sec_color = "FARBE", s_bright = "Helligkeit", s_contrast = "Kontrast",
s_sat = "Sättigung", fx_presets = "FARB-VOREINSTELLUNGEN",
p_normal = "NORMAL", p_cinema = "KINO", p_bw = "S/W", p_cold = "KALT", p_warm = "WARM",
fx_reset = "ALLE EFFEKTE ZURÜCKSETZEN",
cfg_lang = "SPRACHE", cfg_theme = "DESIGN", th_red = "ROT / SCHWARZ", th_mono = "SCHWARZ / WEISS",
cfg_reset = "MENÜPOSITION ZURÜCKSETZEN", sec_about = "INFO",
st_off = "STATUS: AUS", st_spect = "SPEKT: %s", st_dist = "ABST %.0f", st_path = "PFAD %d%%",
st_trans = "ÜBERGANG", st_free = "AKTIV - FREI", st_vel = "TEMPO: %s %.0f",
sp_normal = "NORMAL", sp_fast = "SCHNELL", sp_slow = "LANGSAM",
n_activate = "FREECAM AKTIVIEREN", n_stoppath = "ERST PFAD STOPPEN", n_point = "PUNKT #%d",
n_cleared = "PFAD GELÖSCHT", n_min2 = "MIN. 2 PUNKTE", n_pathstop = "PFAD GESTOPPT",
n_saved = "IN SLOT %d GESPEICHERT", n_slotempty = "SLOT %d LEER", n_noplayers = "KEINE ANDEREN SPIELER",
n_playerleft = "SPIELER HAT VERLASSEN", n_exitspect = "ERST ZUSCHAUEN BEENDEN", n_nochar = "FIGUR NICHT GEFUNDEN",
n_tp = "TELEPORTIERT!", n_failed = "FEHLGESCHLAGEN",
}
K.str.zh = {
tab_camera = "相机", tab_spect = "观战", tab_path = "路径", tab_fx = "特效", tab_cfg = "设置",
cam_on = "开启自由相机  [P]", cam_off = "关闭自由相机  [P]",
cam_tp = "将角色传送到相机  [T]", cam_back = "相机回到角色  [G]",
sec_view = "视角与移动", s_fov = "视野 (FOV)", s_roll = "倾斜 (度)",
s_speed = "基础速度", t_hide = "隐藏我的角色 [H]", t_stream = "加载相机周围的地图",
cam_goto = "前往已保存位置 (按键 1-5)", cam_save = "在此保存位置 (CTRL + 1-5)",
sec_help = "操作说明",
cam_help = "WASD 移动 | Q/E 下降/上升 | SHIFT 慢速 | 空格 快速\n右键 环视 | 滚轮 缩放 | CTRL+滚轮 速度 | Z/C 倾斜\nT 传送 | G 相机->角色 | H 隐藏角色 | R 重置\nV/[ ] 观战 | K/L 路径 | X 停止 | RShift 显示/隐藏菜单",
sp_hint = "点击玩家，或在相机中使用 V 与 [ ]。",
sp_follow = "跟随", sp_orbit = "环绕", sp_first = "第一人称",
sp_exit = "退出观战  [X]", s_dist = "相机距离",
s_orbit = "环绕速度", sp_players = "服务器玩家",
path_add = "+ 在此添加路径点  [K]", path_play = "播放路径  [L]", path_stop = "停止路径  [L]",
path_info = "路径点: %d   |   时长: %.1f秒", s_dur = "总时长 (秒)",
t_smooth = "起止平滑", t_loop = "循环播放",
path_clear = "清除路径点",
path_help = "将相机放到想要的位置，在每个点按 K（至少 2 个），然后播放路径。相机会沿平滑曲线经过所有点，FOV 和倾斜也会插值。播放时可按 L、X 或按钮停止。",
sec_effects = "屏幕特效", s_bars = "电影黑边 (%)", s_blur = "模糊",
s_bloom = "泛光", s_dof = "背景虚化 (DOF)", s_focus = "对焦距离",
s_shake = "镜头抖动", sec_color = "色彩", s_bright = "亮度", s_contrast = "对比度",
s_sat = "饱和度", fx_presets = "色彩预设",
p_normal = "默认", p_cinema = "电影", p_bw = "黑白", p_cold = "冷色", p_warm = "暖色",
fx_reset = "重置所有特效",
cfg_lang = "语言", cfg_theme = "主题", th_red = "红 / 黑", th_mono = "黑 / 白",
cfg_reset = "重置菜单位置", sec_about = "关于",
st_off = "状态: 关闭", st_spect = "观战: %s", st_dist = "距离 %.0f", st_path = "路径 %d%%",
st_trans = "过渡中", st_free = "已开启 - 自由", st_vel = "速度: %s %.0f",
sp_normal = "正常", sp_fast = "快速", sp_slow = "慢速",
n_activate = "请先开启自由相机", n_stoppath = "请先停止路径", n_point = "路径点 #%d",
n_cleared = "路径已清除", n_min2 = "至少需要 2 个点", n_pathstop = "路径已停止",
n_saved = "已保存到位置 %d", n_slotempty = "位置 %d 为空", n_noplayers = "没有其他玩家",
n_playerleft = "玩家已离开", n_exitspect = "请先退出观战", n_nochar = "未找到角色",
n_tp = "已传送!", n_failed = "失败",
}
K.str.ja = {
tab_camera = "カメラ", tab_spect = "観戦", tab_path = "パス", tab_fx = "FX", tab_cfg = "設定",
cam_on = "フリーカメラ ON  [P]", cam_off = "フリーカメラ OFF  [P]",
cam_tp = "キャラをカメラへテレポート  [T]", cam_back = "カメラをキャラに戻す  [G]",
sec_view = "視点と移動", s_fov = "視野角 (FOV)", s_roll = "傾き (度)",
s_speed = "基本速度", t_hide = "自分のキャラを隠す [H]", t_stream = "カメラ周辺のマップを読み込む",
cam_goto = "保存位置へ移動 (キー 1-5)", cam_save = "ここに位置を保存 (CTRL + 1-5)",
sec_help = "操作方法",
cam_help = "WASD 移動 | Q/E 下降/上昇 | SHIFT 低速 | SPACE 高速\n右クリック 視点 | スクロール ズーム | CTRL+スクロール 速度 | Z/C 傾き\nT テレポート | G カメラ->キャラ | H キャラ非表示 | R リセット\nV/[ ] 観戦 | K/L パス | X 停止 | RShift メニュー表示切替",
sp_hint = "プレイヤーをクリック、またはカメラ中に V と [ ] を使用。",
sp_follow = "追従", sp_orbit = "周回", sp_first = "一人称",
sp_exit = "観戦を終了  [X]", s_dist = "カメラ距離",
s_orbit = "周回速度", sp_players = "サーバー内のプレイヤー",
path_add = "+ ここにポイントを追加  [K]", path_play = "パス再生  [L]", path_stop = "パス停止  [L]",
path_info = "ポイント: %d   |   長さ: %.1f秒", s_dur = "合計時間 (秒)",
t_smooth = "開始と終了をなめらかに", t_loop = "ループ再生",
path_clear = "ポイントを消去",
path_help = "カメラを配置し、各ポイントで K を押して（最低 2 点）パスを再生します。カメラは滑らかな曲線ですべてのポイントを通過し、FOV と傾きも補間されます。再生中は L、X、またはボタンで停止できます。",
sec_effects = "画面エフェクト", s_bars = "シネマバー (%)", s_blur = "ぼかし",
s_bloom = "ブルーム", s_dof = "背景ぼかし (DOF)", s_focus = "ピント距離",
s_shake = "カメラ揺れ", sec_color = "カラー", s_bright = "明るさ", s_contrast = "コントラスト",
s_sat = "彩度", fx_presets = "カラープリセット",
p_normal = "標準", p_cinema = "シネマ", p_bw = "白黒", p_cold = "寒色", p_warm = "暖色",
fx_reset = "全エフェクトをリセット",
cfg_lang = "言語", cfg_theme = "テーマ", th_red = "赤 / 黒", th_mono = "黒 / 白",
cfg_reset = "メニュー位置をリセット", sec_about = "情報",
st_off = "状態: OFF", st_spect = "観戦: %s", st_dist = "距離 %.0f", st_path = "パス %d%%",
st_trans = "移動中", st_free = "ON - フリー", st_vel = "速度: %s %.0f",
sp_normal = "通常", sp_fast = "高速", sp_slow = "低速",
n_activate = "フリーカメラをONにしてください", n_stoppath = "先にパスを停止してください", n_point = "ポイント #%d",
n_cleared = "パスを消去しました", n_min2 = "最低 2 ポイント必要です", n_pathstop = "パス停止",
n_saved = "スロット %d に保存", n_slotempty = "スロット %d は空です", n_noplayers = "他のプレイヤーがいません",
n_playerleft = "プレイヤーが退出しました", n_exitspect = "先に観戦を終了してください", n_nochar = "キャラが見つかりません",
n_tp = "テレポート完了!", n_failed = "失敗",
}
do
local prefs = env.CAMHUB_FREECAM_PREFS
if type(prefs) ~= "table" then
prefs = {}
env.CAMHUB_FREECAM_PREFS = prefs
end
if not K.str[prefs.lang] then
prefs.lang = "pt"
end
if not K.themes[prefs.theme] then
prefs.theme = "red"
end
K.prefs = prefs
K.lang = prefs.lang
K.theme = prefs.theme
for key, value in pairs(K.themes[K.theme]) do
C[key] = value
end
end
local function T(key, ...)
local pack = K.str[K.lang]
local text = (pack and pack[key]) or K.str.en[key] or K.str.pt[key] or key
if select("#", ...) > 0 then
local ok, result = pcall(string.format, text, ...)
if ok then
return result
end
end
return text
end
K.info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
function K.tween(inst, props, info)
local ok, tween = pcall(TweenService.Create, TweenService, inst, info or K.info, props)
if ok and tween then
tween:Play()
end
end
function K.onTheme(fn)
K.themeHooks[fn] = true
fn()
return fn
end
function K.onLang(fn)
K.langHooks[fn] = true
fn()
return fn
end
function K.setTheme(name)
local theme = K.themes[name]
if not theme then return end
K.theme = name
K.prefs.theme = name
for key, value in pairs(theme) do
C[key] = value
end
for fn in pairs(K.themeHooks) do
pcall(fn)
end
refreshStatus()
end
function K.setLang(code)
if not K.str[code] then return end
K.lang = code
K.prefs.lang = code
for fn in pairs(K.langHooks) do
pcall(fn)
end
refreshStatus()
end
local gui, fxGui
do
local guiParent
pcall(function()
if type(gethui) == "function" then
guiParent = gethui()
end
end)
if not guiParent then
pcall(function()
guiParent = game:GetService("CoreGui")
end)
end
if not guiParent then
guiParent = playerGui
end
gui = mk("ScreenGui", {
Name = "CAMHUB_CINEMATIC_FREECAM",
ResetOnSpawn = false,
DisplayOrder = 999999,
ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)
fxGui = mk("ScreenGui", {
Name = "CAMHUB_CINEMATIC_FX",
ResetOnSpawn = false,
DisplayOrder = 999998,
IgnoreGuiInset = true,
ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)
end
do
local barTop = mk("Frame", {
Size = UDim2.new(1, 0, 0, 0),
BackgroundColor3 = Color3.new(0, 0, 0),
BorderSizePixel = 0,
Visible = false,
}, fxGui)
local barBottom = mk("Frame", {
AnchorPoint = Vector2.new(0, 1),
Position = UDim2.fromScale(0, 1),
Size = UDim2.new(1, 0, 0, 0),
BackgroundColor3 = Color3.new(0, 0, 0),
BorderSizePixel = 0,
Visible = false,
}, fxGui)
function ui.setBars(percent)
local scale = math.clamp(percent, 0, 30) / 100
barTop.Size = UDim2.new(1, 0, scale, 0)
barBottom.Size = UDim2.new(1, 0, scale, 0)
barTop.Visible = scale > 0
barBottom.Visible = scale > 0
end
local toast = mk("Frame", {
AnchorPoint = Vector2.new(0.5, 1),
Position = UDim2.new(0.5, 0, 1, -70),
Size = UDim2.fromOffset(0, 32),
AutomaticSize = Enum.AutomaticSize.X,
BackgroundColor3 = C.bg,
BackgroundTransparency = 1,
BorderSizePixel = 0,
Visible = false,
ZIndex = 10,
}, fxGui)
round(toast, 8)
mk("UIPadding", {
PaddingLeft = UDim.new(0, 16),
PaddingRight = UDim.new(0, 16),
}, toast)
local toastStroke = mk("UIStroke", {
Color = C.accent,
Thickness = 1.5,
Transparency = 1,
ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, toast)
local toastLabel = mk("TextLabel", {
Size = UDim2.new(0, 0, 1, 0),
AutomaticSize = Enum.AutomaticSize.X,
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.text,
Font = Enum.Font.GothamBold,
TextSize = 13,
TextTransparency = 1,
ZIndex = 11,
}, toast)
K.onTheme(function()
toast.BackgroundColor3 = C.bg
toastStroke.Color = C.accent
toastLabel.TextColor3 = C.text
end)
local toastToken = 0
function ui.toast(text)
toastToken += 1
local token = toastToken
toastLabel.Text = text
toast.Visible = true
K.tween(toast, { BackgroundTransparency = 0.12 })
K.tween(toastStroke, { Transparency = 0.2 })
K.tween(toastLabel, { TextTransparency = 0 })
task.delay(1.6, function()
if toastToken ~= token then return end
K.tween(toast, { BackgroundTransparency = 1 })
K.tween(toastStroke, { Transparency = 1 })
K.tween(toastLabel, { TextTransparency = 1 })
task.delay(0.25, function()
if toastToken == token then
toast.Visible = false
end
end)
end)
end
end
local fx = {}
do
local function createEffect(key, className, props)
local ok, inst = pcall(function()
local effect = Instance.new(className)
for k, v in pairs(props) do
effect[k] = v
end
effect.Parent = Lighting
return effect
end)
if ok then
fx[key] = inst
end
end
createEffect("blur", "BlurEffect", { Name = "CAMHUB_Blur", Size = 0, Enabled = false })
createEffect("bloom", "BloomEffect", { Name = "CAMHUB_Bloom", Intensity = 0, Size = 24, Threshold = 0.9, Enabled = false })
createEffect("color", "ColorCorrectionEffect", { Name = "CAMHUB_Color", Enabled = false })
createEffect("dof", "DepthOfFieldEffect", {
Name = "CAMHUB_DOF",
FarIntensity = 0,
NearIntensity = 0,
FocusDistance = 40,
InFocusRadius = 15,
Enabled = false,
})
end
do
local TEXT_FONT = Enum.Font.Gotham
local BOLD_FONT = Enum.Font.GothamBold
local ALIGN_LEFT = Enum.TextXAlignment.Left
local ALIGN_RIGHT = Enum.TextXAlignment.Right
local STROKE_BORDER = Enum.ApplyStrokeMode.Border
local tween = K.tween
local onTheme = K.onTheme
local onLang = K.onLang
local orderCount = setmetatable({}, { __mode = "k" })
local function nextOrder(parent)
orderCount[parent] = (orderCount[parent] or 0) + 1
return orderCount[parent]
end
local function newLabel(parent, key, colorKey, textSize, bold)
local label = mk("TextLabel", {
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundTransparency = 1,
Text = "",
TextColor3 = C[colorKey],
Font = bold and BOLD_FONT or TEXT_FONT,
TextSize = textSize or 11,
TextWrapped = true,
TextXAlignment = ALIGN_LEFT,
TextYAlignment = Enum.TextYAlignment.Top,
LayoutOrder = nextOrder(parent),
}, parent)
onTheme(function()
label.TextColor3 = C[colorKey]
end)
if key then
onLang(function()
label.Text = T(key)
end)
end
return label
end
local function newSection(parent, key)
local holder = mk("Frame", {
Size = UDim2.new(1, 0, 0, 24),
BackgroundTransparency = 1,
LayoutOrder = nextOrder(parent),
}, parent)
local label = mk("TextLabel", {
Size = UDim2.new(1, 0, 0, 16),
Position = UDim2.fromOffset(0, 5),
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.accent,
Font = BOLD_FONT,
TextSize = 10,
TextXAlignment = ALIGN_LEFT,
TextTruncate = Enum.TextTruncate.AtEnd,
}, holder)
local line = mk("Frame", {
Size = UDim2.new(1, 0, 0, 1),
Position = UDim2.new(0, 0, 1, -1),
BackgroundColor3 = C.accent,
BackgroundTransparency = 0.7,
BorderSizePixel = 0,
}, holder)
onTheme(function()
label.TextColor3 = C.accent
line.BackgroundColor3 = C.accent
end)
onLang(function()
label.Text = T(key)
end)
return holder
end
local function buildButton(parent, size, position, callback, primary, textSize)
local state = {
selected = false,
primary = primary and true or false,
dim = false,
hover = false,
down = false,
}
local textKey
local rawText
local button = mk("TextButton", {
Size = size,
Position = position or UDim2.new(),
BackgroundColor3 = C.panel,
BorderSizePixel = 0,
Text = "",
TextColor3 = C.text,
Font = BOLD_FONT,
TextSize = textSize or 11,
TextTruncate = Enum.TextTruncate.AtEnd,
AutoButtonColor = false,
}, parent)
round(button, 7)
local stroke = mk("UIStroke", {
Color = C.line,
Thickness = 1,
Transparency = 0.55,
ApplyStrokeMode = STROKE_BORDER,
}, button)
local obj = { gui = button }
local function render(instant)
local bg, textColor
if state.selected then
bg, textColor = C.sel, C.selText
elseif state.primary then
bg, textColor = C.primary, C.primaryText
else
bg, textColor = C.panel, C.text
end
local strokeColor, strokeAlpha, strokeSize = C.line, 0.55, 1
if state.hover then
bg = bg:Lerp(C.accent, 0.16)
strokeColor, strokeAlpha, strokeSize = C.accent, 0, 2
end
if state.down then
bg = bg:Lerp(C.accent, 0.3)
end
local textAlpha = state.dim and 0.5 or 0
if instant then
button.BackgroundColor3 = bg
button.TextColor3 = textColor
button.TextTransparency = textAlpha
stroke.Color = strokeColor
stroke.Transparency = strokeAlpha
stroke.Thickness = strokeSize
else
tween(button, { BackgroundColor3 = bg, TextColor3 = textColor, TextTransparency = textAlpha })
tween(stroke, { Color = strokeColor, Transparency = strokeAlpha, Thickness = strokeSize })
end
end
local function applyText()
local text = rawText or (textKey and T(textKey)) or ""
if button.Text ~= text then
button.Text = text
end
end
local function themeHook()
render(true)
end
K.themeHooks[themeHook] = true
K.langHooks[applyText] = true
render(true)
function obj.setKey(key)
if textKey == key and rawText == nil then return end
textKey = key
rawText = nil
applyText()
end
function obj.setRaw(text)
if rawText == text then return end
rawText = text
applyText()
end
function obj.setSelected(value)
value = value and true or false
if state.selected == value then return end
state.selected = value
render()
end
function obj.setPrimary(value)
value = value and true or false
if state.primary == value then return end
state.primary = value
render()
end
function obj.setDim(value)
value = value and true or false
if state.dim == value then return end
state.dim = value
render()
end
function obj.destroy()
K.themeHooks[themeHook] = nil
K.langHooks[applyText] = nil
pcall(function()
button:Destroy()
end)
end
table.insert(connections, button.MouseEnter:Connect(function()
state.hover = true
render()
end))
table.insert(connections, button.MouseLeave:Connect(function()
state.hover = false
state.down = false
render()
end))
table.insert(connections, button.MouseButton1Down:Connect(function()
state.down = true
render()
end))
table.insert(connections, button.MouseButton1Up:Connect(function()
state.down = false
render()
end))
if callback then
table.insert(connections, button.MouseButton1Click:Connect(callback))
end
return obj
end
local function newButton(parent, key, height, callback, primary)
local obj = buildButton(parent, UDim2.new(1, 0, 0, height or 30), nil, callback, primary)
obj.gui.LayoutOrder = nextOrder(parent)
if key then
obj.setKey(key)
end
return obj
end
local function newRow(parent, height, items, callback, textSize)
local row = mk("Frame", {
Size = UDim2.new(1, 0, 0, height),
BackgroundTransparency = 1,
LayoutOrder = nextOrder(parent),
}, parent)
local count = #items
local buttons = {}
for index, item in ipairs(items) do
local obj = buildButton(
row,
UDim2.new(1 / count, -4, 1, 0),
UDim2.new((index - 1) / count, 2, 0, 0),
function()
callback(index)
end,
false,
textSize
)
if item.key then
obj.setKey(item.key)
else
obj.setRaw(item.raw)
end
buttons[index] = obj
end
return buttons, row
end
local function newToggle(parent, key, default, onChange)
local state = default and true or false
local hover = false
local row = mk("TextButton", {
Size = UDim2.new(1, 0, 0, 30),
BackgroundColor3 = C.panel,
BorderSizePixel = 0,
Text = "",
AutoButtonColor = false,
LayoutOrder = nextOrder(parent),
}, parent)
round(row, 7)
local stroke = mk("UIStroke", {
Color = C.line,
Thickness = 1,
Transparency = 0.55,
ApplyStrokeMode = STROKE_BORDER,
}, row)
local label = mk("TextLabel", {
Size = UDim2.new(1, -60, 1, 0),
Position = UDim2.fromOffset(10, 0),
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.text,
Font = TEXT_FONT,
TextSize = 11,
TextXAlignment = ALIGN_LEFT,
TextTruncate = Enum.TextTruncate.AtEnd,
}, row)
local pill = mk("Frame", {
Size = UDim2.fromOffset(34, 16),
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -10, 0.5, 0),
BackgroundColor3 = C.track,
BorderSizePixel = 0,
}, row)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
local knob = mk("Frame", {
Size = UDim2.fromOffset(12, 12),
AnchorPoint = Vector2.new(0, 0.5),
Position = UDim2.new(0, 2, 0.5, 0),
BackgroundColor3 = C.knobOff,
BorderSizePixel = 0,
}, pill)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
local obj = {}
local function render(instant)
local bg = C.panel
local pillColor = state and C.accent or C.track
local knobColor = state and C.knobOn or C.knobOff
local knobPos = UDim2.new(0, state and 20 or 2, 0.5, 0)
local strokeColor, strokeAlpha, strokeSize = C.line, 0.55, 1
if hover then
bg = bg:Lerp(C.accent, 0.12)
strokeColor, strokeAlpha, strokeSize = C.accent, 0, 2
end
if instant then
row.BackgroundColor3 = bg
pill.BackgroundColor3 = pillColor
knob.BackgroundColor3 = knobColor
knob.Position = knobPos
stroke.Color = strokeColor
stroke.Transparency = strokeAlpha
stroke.Thickness = strokeSize
else
tween(row, { BackgroundColor3 = bg })
tween(pill, { BackgroundColor3 = pillColor })
tween(knob, { BackgroundColor3 = knobColor, Position = knobPos })
tween(stroke, { Color = strokeColor, Transparency = strokeAlpha, Thickness = strokeSize })
end
end
function obj.set(value, silent)
state = value and true or false
render()
if not silent and onChange then
onChange(state)
end
end
function obj.get()
return state
end
table.insert(connections, row.MouseButton1Click:Connect(function()
obj.set(not state)
end))
table.insert(connections, row.MouseEnter:Connect(function()
hover = true
render()
end))
table.insert(connections, row.MouseLeave:Connect(function()
hover = false
render()
end))
onTheme(function()
label.TextColor3 = C.text
render(true)
end)
onLang(function()
label.Text = T(key)
end)
return obj
end
local function newSlider(parent, key, minValue, maxValue, default, step, format, onChange)
local holder = mk("Frame", {
Size = UDim2.new(1, 0, 0, 40),
BackgroundTransparency = 1,
LayoutOrder = nextOrder(parent),
}, parent)
local label = mk("TextLabel", {
Size = UDim2.new(1, -64, 0, 16),
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.text,
Font = TEXT_FONT,
TextSize = 11,
TextXAlignment = ALIGN_LEFT,
TextTruncate = Enum.TextTruncate.AtEnd,
}, holder)
local valueLabel = mk("TextLabel", {
Size = UDim2.fromOffset(60, 16),
AnchorPoint = Vector2.new(1, 0),
Position = UDim2.new(1, 0, 0, 0),
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.accent,
Font = BOLD_FONT,
TextSize = 11,
TextXAlignment = ALIGN_RIGHT,
}, holder)
local hit = mk("TextButton", {
Size = UDim2.new(1, 0, 0, 20),
Position = UDim2.fromOffset(0, 18),
BackgroundTransparency = 1,
Text = "",
AutoButtonColor = false,
}, holder)
local bar = mk("Frame", {
Size = UDim2.new(1, -14, 0, 6),
Position = UDim2.new(0, 7, 0.5, -3),
BackgroundColor3 = C.track,
BorderSizePixel = 0,
}, hit)
round(bar, 3)
local fill = mk("Frame", {
Size = UDim2.new(0, 0, 1, 0),
BackgroundColor3 = C.accent,
BorderSizePixel = 0,
}, bar)
round(fill, 3)
local knob = mk("Frame", {
Size = UDim2.fromOffset(12, 12),
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(0, 0, 0.5, 0),
BackgroundColor3 = C.text,
BorderSizePixel = 0,
ZIndex = 2,
}, bar)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
local knobStroke = mk("UIStroke", {
Color = C.accent,
Thickness = 0,
Transparency = 0.2,
ApplyStrokeMode = STROKE_BORDER,
}, knob)
local obj = { value = default }
local hover = false
local dragging = false
local function renderKnob()
local big = hover or dragging
tween(knob, { Size = big and UDim2.fromOffset(16, 16) or UDim2.fromOffset(12, 12) })
tween(knobStroke, { Thickness = big and 3 or 0 })
end
local function render()
local alpha = math.clamp((obj.value - minValue) / (maxValue - minValue), 0, 1)
fill.Size = UDim2.new(alpha, 0, 1, 0)
knob.Position = UDim2.new(alpha, 0, 0.5, 0)
label.Text = T(key)
valueLabel.Text = string.format(format, obj.value)
end
function obj.set(value, silent)
value = math.clamp(value, minValue, maxValue)
if step then
value = math.floor(value / step + 0.5) * step
end
if silent and value == obj.value then
return
end
obj.value = value
render()
if not silent and onChange then
onChange(value)
end
end
local function fromX(x)
local width = math.max(bar.AbsoluteSize.X, 1)
local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
obj.set(minValue + (maxValue - minValue) * alpha)
end
table.insert(connections, hit.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
activeSlider = fromX
K.endSlider = function()
dragging = false
renderKnob()
end
renderKnob()
fromX(input.Position.X)
end
end))
table.insert(connections, hit.MouseEnter:Connect(function()
hover = true
renderKnob()
end))
table.insert(connections, hit.MouseLeave:Connect(function()
hover = false
renderKnob()
end))
onTheme(function()
label.TextColor3 = C.text
valueLabel.TextColor3 = C.accent
bar.BackgroundColor3 = C.track
fill.BackgroundColor3 = C.accent
knob.BackgroundColor3 = C.text
knobStroke.Color = C.accent
end)
onLang(render)
return obj
end
local main = mk("Frame", {
Size = UDim2.fromOffset(WIDTH, FULL_HEIGHT),
Position = UDim2.fromOffset(25, 120),
BackgroundColor3 = C.bg,
BorderSizePixel = 0,
ClipsDescendants = true,
}, gui)
round(main, 12)
local mainStroke = mk("UIStroke", {
Color = C.accent,
Thickness = 1.5,
Transparency = 0.15,
ApplyStrokeMode = STROKE_BORDER,
}, main)
local mainScale = mk("UIScale", { Scale = 0.92 }, main)
local header = mk("Frame", {
Size = UDim2.new(1, 0, 0, 40),
BackgroundColor3 = C.header,
BorderSizePixel = 0,
}, main)
round(header, 12)
local headerCover = mk("Frame", {
Size = UDim2.new(1, 0, 0, 12),
Position = UDim2.new(0, 0, 1, -12),
BackgroundColor3 = C.header,
BorderSizePixel = 0,
}, header)
local headerLine = mk("Frame", {
Size = UDim2.new(1, 0, 0, 2),
Position = UDim2.fromOffset(0, 40),
BackgroundColor3 = C.accent,
BorderSizePixel = 0,
}, main)
mk("UIGradient", {
Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0),
NumberSequenceKeypoint.new(1, 0.85),
}),
}, headerLine)
ui.statusDot = mk("Frame", {
Size = UDim2.fromOffset(10, 10),
Position = UDim2.fromOffset(14, 15),
BackgroundColor3 = C.bad,
BorderSizePixel = 0,
}, header)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, ui.statusDot)
local title = mk("TextLabel", {
Size = UDim2.new(1, -90, 1, 0),
Position = UDim2.fromOffset(32, 0),
BackgroundTransparency = 1,
Text = "CamHub  //  FREECAM STUDIO",
RichText = true,
TextColor3 = C.text,
Font = BOLD_FONT,
TextSize = 13,
TextXAlignment = ALIGN_LEFT,
TextTruncate = Enum.TextTruncate.AtEnd,
}, header)
local minimizeButton = buildButton(
header,
UDim2.fromOffset(30, 26),
UDim2.new(1, -40, 0, 7),
nil,
false,
18
)
minimizeButton.setRaw("-")
onTheme(function()
mainStroke.Color = C.accent
main.BackgroundColor3 = C.bg
header.BackgroundColor3 = C.header
headerCover.BackgroundColor3 = C.header
headerLine.BackgroundColor3 = C.accent
title.TextColor3 = C.text
local ok, hex = pcall(function()
return C.accent:ToHex()
end)
if ok and hex then
title.Text = '<font color="#' .. hex .. '">CamHub</font>  //  FREECAM STUDIO'
else
title.Text = "CamHub  //  FREECAM STUDIO"
end
end)
pcall(function()
TweenService:Create(
mainStroke,
TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
{ Transparency = 0.65 }
):Play()
end)
tween(mainScale, { Scale = 1 }, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
local body = mk("Frame", {
Size = UDim2.new(1, 0, 0, FULL_HEIGHT - 42),
Position = UDim2.fromOffset(0, 42),
BackgroundTransparency = 1,
}, main)
ui.statusLeft = mk("TextLabel", {
Size = UDim2.new(0.55, -12, 0, 20),
Position = UDim2.fromOffset(12, 3),
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.bad,
Font = BOLD_FONT,
TextSize = 11,
TextXAlignment = ALIGN_LEFT,
TextTruncate = Enum.TextTruncate.AtEnd,
}, body)
ui.statusRight = mk("TextLabel", {
Size = UDim2.new(0.45, -12, 0, 20),
Position = UDim2.new(0.55, 0, 0, 3),
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.note,
Font = BOLD_FONT,
TextSize = 10,
TextXAlignment = ALIGN_RIGHT,
TextTruncate = Enum.TextTruncate.AtEnd,
}, body)
onTheme(function()
ui.statusRight.TextColor3 = C.note
end)
local tabBar = mk("Frame", {
Size = UDim2.new(1, -12, 0, 26),
Position = UDim2.fromOffset(6, 26),
BackgroundTransparency = 1,
}, body)
local pagesHolder = mk("Frame", {
Size = UDim2.new(1, 0, 1, -58),
Position = UDim2.fromOffset(0, 58),
BackgroundTransparency = 1,
}, body)
local pages = {}
local tabButtons = {}
local function newPage()
local page = mk("ScrollingFrame", {
Size = UDim2.new(1, 0, 1, 0),
BackgroundTransparency = 1,
BorderSizePixel = 0,
ScrollBarThickness = 3,
ScrollBarImageColor3 = C.accent,
CanvasSize = UDim2.new(),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
ScrollingDirection = Enum.ScrollingDirection.Y,
Visible = false,
}, pagesHolder)
mk("UIListLayout", {
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
}, page)
mk("UIPadding", {
PaddingLeft = UDim.new(0, 10),
PaddingRight = UDim.new(0, 13),
PaddingTop = UDim.new(0, 5),
PaddingBottom = UDim.new(0, 10),
}, page)
onTheme(function()
page.ScrollBarImageColor3 = C.accent
end)
table.insert(pages, page)
return page
end
function ui.showTab(index)
for i, page in ipairs(pages) do
page.Visible = i == index
tabButtons[i].setSelected(i == index)
end
end
local pageCamera = newPage()
local pageSpect = newPage()
local pagePath = newPage()
local pageFx = newPage()
local pageCfg = newPage()
do
local tabKeys = { "tab_camera", "tab_spect", "tab_path", "tab_fx", "tab_cfg" }
for index, key in ipairs(tabKeys) do
local obj = buildButton(
tabBar,
UDim2.new(1 / #tabKeys, -4, 1, 0),
UDim2.new((index - 1) / #tabKeys, 2, 0, 0),
function()
ui.showTab(index)
end,
false,
10
)
obj.setKey(key)
tabButtons[index] = obj
end
end
local function numberItems(count)
local items = {}
for index = 1, count do
items[index] = { raw = tostring(index) }
end
return items
end
ui.toggleButton = newButton(pageCamera, "cam_on", 36, function()
setFreecam(not active)
end, true)
ui.tpButton = newButton(pageCamera, "cam_tp", 30, function()
task.spawn(teleportToCamera)
end)
newButton(pageCamera, "cam_back", 28, function()
cameraToCharacter()
end)
newSection(pageCamera, "sec_view")
ui.fovSlider = newSlider(pageCamera, "s_fov", MIN_FOV, MAX_FOV, 70, 1, "%.0f", function(value)
targetFOV = value
end)
ui.rollSlider = newSlider(pageCamera, "s_roll", -MAX_ROLL_DEG, MAX_ROLL_DEG, 0, 1, "%.0f", function(value)
targetRoll = math.rad(value)
end)
ui.speedSlider = newSlider(pageCamera, "s_speed", 5, 150, DEFAULT_BASE_SPEED, 1, "%.0f", function(value)
baseSpeed = value
end)
ui.hideToggle = newToggle(pageCamera, "t_hide", false, function(state)
hideSelf = state
if active then
applyHideSelf(state)
end
end)
newSection(pageCamera, "cam_goto")
ui.slotGo = newRow(pageCamera, 28, numberItems(SLOT_COUNT), function(index)
gotoSlot(index)
end, 12)
newSection(pageCamera, "cam_save")
ui.slotSave = newRow(pageCamera, 28, numberItems(SLOT_COUNT), function(index)
saveSlot(index)
end, 12)
newSection(pageCamera, "sec_help")
newLabel(pageCamera, "cam_help", "sub", 10)
newLabel(pageSpect, "sp_hint", "sub", 10)
ui.specModeButtons = newRow(pageSpect, 28, {
{ key = "sp_follow" },
{ key = "sp_orbit" },
{ key = "sp_first" },
}, function(index)
specMode = index
specFPCF = nil
ui.refreshSpecModeButtons()
end, 10)
function ui.refreshSpecModeButtons()
for index, obj in ipairs(ui.specModeButtons) do
obj.setSelected(index == specMode)
end
end
newButton(pageSpect, "sp_exit", 28, function()
if mode == "spectate" then
exitSpectate()
end
end)
ui.distSlider = newSlider(pageSpect, "s_dist", 3, 60, specDist, 1, "%.0f", function(value)
specDist = value
end)
ui.orbitSlider = newSlider(pageSpect, "s_orbit", 0.1, 1.5, orbitSpeed, 0.05, "%.2f", function(value)
orbitSpeed = value
end)
ui.streamToggle = newToggle(pageSpect, "t_stream", streamEnabled, function(state)
streamEnabled = state
streamLastPos = nil
end)
newSection(pageSpect, "sp_players")
local playerButtons = {}
function ui.refreshPlayers()
for p, obj in pairs(playerButtons) do
obj.setSelected(mode == "spectate" and p == specTarget)
end
end
function ui.addPlayerButton(p)
if p == player or playerButtons[p] then return end
local obj = newButton(pageSpect, nil, 28, function()
startSpectate(p)
end)
obj.setRaw(p.DisplayName .. "  (@" .. p.Name .. ")")
playerButtons[p] = obj
end
function ui.removePlayerButton(p)
local obj = playerButtons[p]
if obj then
playerButtons[p] = nil
obj.destroy()
end
end
do
local card = mk("Frame", {
Size = UDim2.new(1, 0, 0, 34),
BackgroundColor3 = C.panel,
BorderSizePixel = 0,
LayoutOrder = nextOrder(pagePath),
}, pagePath)
round(card, 7)
local cardStroke = mk("UIStroke", {
Color = C.line,
Thickness = 1,
Transparency = 0.55,
ApplyStrokeMode = STROKE_BORDER,
}, card)
ui.pathLabel = mk("TextLabel", {
Size = UDim2.new(1, -16, 1, 0),
Position = UDim2.fromOffset(8, 0),
BackgroundTransparency = 1,
Text = "",
TextColor3 = C.text,
Font = BOLD_FONT,
TextSize = 11,
TextTruncate = Enum.TextTruncate.AtEnd,
}, card)
onTheme(function()
card.BackgroundColor3 = C.panel
cardStroke.Color = C.line
ui.pathLabel.TextColor3 = C.text
end)
end
newButton(pagePath, "path_add", 28, function()
addKeyframe()
end)
ui.pathButton = newButton(pagePath, "path_play", 34, function()
togglePath()
end, true)
ui.durationSlider = newSlider(pagePath, "s_dur", 2, 60, pathDuration, 0.5, "%.1f", function(value)
pathDuration = value
ui.refreshPathLabel()
end)
ui.smoothToggle = newToggle(pagePath, "t_smooth", pathSmooth, function(state)
pathSmooth = state
end)
ui.loopToggle = newToggle(pagePath, "t_loop", pathLoop, function(state)
pathLoop = state
end)
newButton(pagePath, "path_clear", 28, function()
clearPath()
end)
newLabel(pagePath, "path_help", "sub", 10)
function ui.refreshPathLabel()
ui.pathLabel.Text = T("path_info", #keyframes, pathDuration)
end
onLang(function()
ui.refreshPathLabel()
end)
do
local WHITE = Color3.new(1, 1, 1)
local colorState = { brightness = 0, contrast = 0, saturation = 0, tint = WHITE }
local dofState = { intensity = 0, distance = 40 }
local function setFx(key, prop, value)
local inst = fx[key]
if inst then
pcall(function()
inst[prop] = value
end)
end
end
local function applyColor()
local isDefault = colorState.brightness == 0
and colorState.contrast == 0
and colorState.saturation == 0
and colorState.tint == WHITE
setFx("color", "Brightness", colorState.brightness)
setFx("color", "Contrast", colorState.contrast)
setFx("color", "Saturation", colorState.saturation)
setFx("color", "TintColor", colorState.tint)
setFx("color", "Enabled", not isDefault)
end
local function applyDof()
setFx("dof", "FarIntensity", dofState.intensity)
setFx("dof", "FocusDistance", dofState.distance)
setFx("dof", "Enabled", dofState.intensity > 0)
end
newSection(pageFx, "sec_effects")
ui.barsSlider = newSlider(pageFx, "s_bars", 0, 20, 0, 0.5, "%.1f", function(value)
ui.setBars(value)
end)
ui.blurSlider = newSlider(pageFx, "s_blur", 0, 30, 0, 1, "%.0f", function(value)
setFx("blur", "Size", value)
setFx("blur", "Enabled", value > 0)
end)
ui.bloomSlider = newSlider(pageFx, "s_bloom", 0, 1.5, 0, 0.05, "%.2f", function(value)
setFx("bloom", "Intensity", value)
setFx("bloom", "Enabled", value > 0)
end)
ui.dofSlider = newSlider(pageFx, "s_dof", 0, 1, 0, 0.05, "%.2f", function(value)
dofState.intensity = value
applyDof()
end)
ui.dofDistSlider = newSlider(pageFx, "s_focus", 5, 300, 40, 1, "%.0f", function(value)
dofState.distance = value
applyDof()
end)
ui.shakeSlider = newSlider(pageFx, "s_shake", 0, 1, 0, 0.05, "%.2f", function(value)
shakeAmount = value
end)
newSection(pageFx, "sec_color")
ui.brightSlider = newSlider(pageFx, "s_bright", -0.3, 0.3, 0, 0.01, "%.2f", function(value)
colorState.brightness = value
applyColor()
end)
ui.contrastSlider = newSlider(pageFx, "s_contrast", -0.5, 1, 0, 0.01, "%.2f", function(value)
colorState.contrast = value
applyColor()
end)
ui.saturationSlider = newSlider(pageFx, "s_sat", -1, 1, 0, 0.01, "%.2f", function(value)
colorState.saturation = value
applyColor()
end)
newSection(pageFx, "fx_presets")
local colorPresets = {
{ key = "p_normal", b = 0, c = 0, s = 0, tint = WHITE },
{ key = "p_cinema", b = -0.02, c = 0.15, s = -0.1, tint = Color3.fromRGB(255, 238, 222) },
{ key = "p_bw", b = 0, c = 0.25, s = -1, tint = WHITE },
{ key = "p_cold", b = 0, c = 0.1, s = -0.05, tint = Color3.fromRGB(205, 225, 255) },
{ key = "p_warm", b = 0.02, c = 0.1, s = 0.1, tint = Color3.fromRGB(255, 222, 190) },
}
local function applyColorPreset(preset)
colorState.brightness = preset.b
colorState.contrast = preset.c
colorState.saturation = preset.s
colorState.tint = preset.tint
ui.brightSlider.set(preset.b, true)
ui.contrastSlider.set(preset.c, true)
ui.saturationSlider.set(preset.s, true)
applyColor()
end
local presetItems = {}
for index, preset in ipairs(colorPresets) do
presetItems[index] = { key = preset.key }
end
newRow(pageFx, 28, presetItems, function(index)
applyColorPreset(colorPresets[index])
end, 9)
newButton(pageFx, "fx_reset", 30, function()
ui.barsSlider.set(0)
ui.blurSlider.set(0)
ui.bloomSlider.set(0)
ui.dofSlider.set(0)
ui.dofDistSlider.set(40)
ui.shakeSlider.set(0)
applyColorPreset(colorPresets[1])
end, true)
end
newSection(pageCfg, "cfg_lang")
ui.langButtons = {}
do
local rowFrame
for index, entry in ipairs(K.langs) do
if index % 2 == 1 then
rowFrame = mk("Frame", {
Size = UDim2.new(1, 0, 0, 30),
BackgroundTransparency = 1,
LayoutOrder = nextOrder(pageCfg),
}, pageCfg)
end
local column = (index - 1) % 2
local obj = buildButton(
rowFrame,
UDim2.new(0.5, -4, 1, 0),
UDim2.new(column * 0.5, 2, 0, 0),
function()
K.setLang(entry.code)
end,
false,
11
)
obj.setRaw(entry.name)
ui.langButtons[entry.code] = obj
end
end
onLang(function()
for code, obj in pairs(ui.langButtons) do
obj.setSelected(code == K.lang)
end
end)
newSection(pageCfg, "cfg_theme")
ui.themeButtons = newRow(pageCfg, 32, {
{ key = "th_red" },
{ key = "th_mono" },
}, function(index)
K.setTheme(index == 1 and "red" or "mono")
end, 10)
onTheme(function()
ui.themeButtons[1].setSelected(K.theme == "red")
ui.themeButtons[2].setSelected(K.theme == "mono")
end)
newButton(pageCfg, "cfg_reset", 30, function()
main.Position = UDim2.fromOffset(25, 120)
end)
newSection(pageCfg, "sec_about")
do
local about = newLabel(pageCfg, nil, "sub", 10)
about.Text = "CamHub // XENO FREECAM STUDIO v4.0\nHUD v2"
end
local dragging = false
local dragStart
local dragStartPos
table.insert(connections, header.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
dragStart = input.Position
dragStartPos = main.Position
end
end))
table.insert(connections, UIS.InputChanged:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.MouseMovement
and input.UserInputType ~= Enum.UserInputType.Touch then
return
end
if activeSlider then
activeSlider(input.Position.X)
end
if dragging then
local delta = input.Position - dragStart
local viewport = gui.AbsoluteSize
local x = math.clamp(dragStartPos.X.Offset + delta.X, 40 - WIDTH, math.max(viewport.X - 40, 0))
local y = math.clamp(dragStartPos.Y.Offset + delta.Y, 0, math.max(viewport.Y - 40, 0))
main.Position = UDim2.fromOffset(x, y)
end
end))
table.insert(connections, UIS.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
dragging = false
if K.endSlider then
local finish = K.endSlider
K.endSlider = nil
finish()
end
activeSlider = nil
end
end))
table.insert(connections, minimizeButton.gui.MouseButton1Click:Connect(function()
minimized = not minimized
body.Visible = not minimized
tween(main, {
Size = minimized
and UDim2.fromOffset(WIDTH, MINI_HEIGHT)
or UDim2.fromOffset(WIDTH, FULL_HEIGHT),
}, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
minimizeButton.setRaw(minimized and "+" or "-")
end))
end
local hudHidden = false
local savedScreenGuis = {}
local savedCoreGuis = {}
local guiAddedConnection
local function hideGameHUD()
if hudHidden then return end
hudHidden = true
for _, coreType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
if coreType ~= Enum.CoreGuiType.All then
local success, previousState = pcall(function()
return StarterGui:GetCoreGuiEnabled(coreType)
end)
if success then
savedCoreGuis[coreType] = previousState
pcall(function()
StarterGui:SetCoreGuiEnabled(coreType, false)
end)
end
end
end
local function hideScreenGui(object)
if object:IsA("ScreenGui") and object ~= gui and object ~= fxGui then
if savedScreenGuis[object] == nil then
savedScreenGuis[object] = object.Enabled
end
object.Enabled = false
end
end
for _, object in ipairs(playerGui:GetChildren()) do
hideScreenGui(object)
end
guiAddedConnection = playerGui.ChildAdded:Connect(function(object)
if hudHidden then
hideScreenGui(object)
end
end)
end
local function restoreGameHUD()
if not hudHidden then return end
hudHidden = false
if guiAddedConnection then
guiAddedConnection:Disconnect()
guiAddedConnection = nil
end
for object, previousState in pairs(savedScreenGuis) do
pcall(function()
object.Enabled = previousState
end)
end
table.clear(savedScreenGuis)
for coreType, previousState in pairs(savedCoreGuis) do
pcall(function()
StarterGui:SetCoreGuiEnabled(coreType, previousState)
end)
end
table.clear(savedCoreGuis)
end
local SINK_ACTION = "CAMHUB_FREECAM_INPUT"
local slotKeys = {
[Enum.KeyCode.One] = 1,
[Enum.KeyCode.Two] = 2,
[Enum.KeyCode.Three] = 3,
[Enum.KeyCode.Four] = 4,
[Enum.KeyCode.Five] = 5,
}
local sunkKeys = {
Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Z, Enum.KeyCode.C,
Enum.KeyCode.Space, Enum.KeyCode.LeftShift,
Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
Enum.KeyCode.T, Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.V, Enum.KeyCode.X,
Enum.KeyCode.K, Enum.KeyCode.L, Enum.KeyCode.R,
Enum.KeyCode.LeftBracket, Enum.KeyCode.RightBracket,
}
local function resetView()
targetFOV = oldFOV or 70
targetRoll = 0
ui.fovSlider.set(targetFOV, true)
ui.rollSlider.set(0, true)
end
local function stopEverything()
if mode == "spectate" then
exitSpectate()
elseif mode == "path" or mode == "goto" then
stopAutomation()
end
end
local function onHotkey(_, state, input)
if state ~= Enum.UserInputState.Begin then
return Enum.ContextActionResult.Sink
end
local key = input.KeyCode
local slot = slotKeys[key]
if slot then
if ctrlDown() then
saveSlot(slot)
else
gotoSlot(slot)
end
elseif key == Enum.KeyCode.T then
task.spawn(teleportToCamera)
elseif key == Enum.KeyCode.G then
cameraToCharacter()
elseif key == Enum.KeyCode.H then
ui.hideToggle.set(not ui.hideToggle.get())
elseif key == Enum.KeyCode.V then
toggleSpectate()
elseif key == Enum.KeyCode.X then
stopEverything()
elseif key == Enum.KeyCode.LeftBracket then
cycleSpectate(-1)
elseif key == Enum.KeyCode.RightBracket then
cycleSpectate(1)
elseif key == Enum.KeyCode.K then
addKeyframe()
elseif key == Enum.KeyCode.L then
togglePath()
elseif key == Enum.KeyCode.R then
resetView()
end
return Enum.ContextActionResult.Sink
end
local function bindInput()
pcall(function()
ContextActionService:BindActionAtPriority(
SINK_ACTION,
onHotkey,
false,
Enum.ContextActionPriority.High.Value + 100,
unpack(sunkKeys)
)
end)
end
local function unbindInput()
pcall(function()
ContextActionService:UnbindAction(SINK_ACTION)
end)
end
local function notify(key, ...)
notifyToken += 1
local token = notifyToken
notifyText = { key = key, args = table.pack(...) }
ui.toast(T(key, ...))
refreshStatus()
task.delay(1.6, function()
if notifyToken == token then
notifyText = nil
if ui.statusRight.Parent then
refreshStatus()
end
end
end)
end
local function pathIsPlaying()
return mode == "path" or (mode == "goto" and trans ~= nil and trans.onDone ~= nil)
end
function refreshStatus()
local left, right
local leftColor = C.good
if not active then
left = T("st_off")
leftColor = C.bad
right = ""
elseif mode == "spectate" then
left = T("st_spect", specTarget and specTarget.DisplayName or "?")
right = T("st_dist", specDist)
elseif mode == "path" then
left = T("st_path", math.floor(pathProgress * 100))
right = ""
elseif mode == "goto" then
left = T("st_trans")
right = ""
else
left = T("st_free")
right = T("st_vel", T(K.speedKeys[currentSpeedMode] or "sp_normal"), currentSpeedValue)
end
if notifyText then
right = T(notifyText.key, table.unpack(notifyText.args, 1, notifyText.args.n))
end
ui.statusLeft.Text = left
ui.statusLeft.TextColor3 = leftColor
ui.statusRight.Text = right
ui.statusDot.BackgroundColor3 = active and C.good or C.bad
ui.toggleButton.setKey(active and "cam_off" or "cam_on")
ui.toggleButton.setPrimary(not active)
ui.tpButton.setPrimary(active)
ui.tpButton.setDim(not active)
ui.pathButton.setKey(pathIsPlaying() and "path_stop" or "path_play")
ui.refreshPlayers()
end
local function refreshSlotButtons()
for index = 1, SLOT_COUNT do
local saved = slots[index] ~= nil
ui.slotGo[index].setSelected(saved)
ui.slotGo[index].setDim(not saved)
end
end
function applyHideSelf(hidden)
local character = player.Character
if not character then return end
for _, object in ipairs(character:GetDescendants()) do
if object:IsA("BasePart") then
pcall(function()
object.LocalTransparencyModifier = hidden and 1 or 0
end)
end
end
end
local function releaseLook()
if lookHeld then
lookHeld = false
UIS.MouseBehavior = oldMouseBehavior or Enum.MouseBehavior.Default
UIS.MouseIconEnabled = oldMouseIconEnabled ~= false
end
end
local function captureKeyframe()
if mode == "spectate" and lastCF then
local look = lastCF.LookVector
local p = lastCF.Position
local kyaw, kpitch = anglesFromLook(look)
return { p.X, p.Y, p.Z, kyaw, kpitch, roll, currentFOV }
end
return { position.X, position.Y, position.Z, yaw, pitch, roll, currentFOV }
end
local function applyChannels(out)
position = Vector3.new(out[1], out[2], out[3])
yaw = out[4]
targetYaw = yaw
pitch = math.clamp(out[5], math.rad(-85), math.rad(85))
targetPitch = pitch
roll = out[6]
targetRoll = roll
currentFOV = math.clamp(out[7], MIN_FOV, MAX_FOV)
targetFOV = currentFOV
end
local function beginTransition(toKeyframe, duration, onDone)
local from = captureKeyframe()
local to = table.clone(toKeyframe)
to[4] = from[4] + angleDiff(from[4], to[4])
position = Vector3.new(from[1], from[2], from[3])
yaw = from[4]
pitch = math.clamp(from[5], math.rad(-85), math.rad(85))
targetYaw, targetPitch = yaw, pitch
targetRoll = roll
targetFOV = currentFOV
trans = {
from = from,
to = to,
duration = math.max(duration, 0.05),
t = 0,
onDone = onDone,
}
mode = "goto"
velocity = Vector3.zero
releaseLook()
refreshStatus()
end
local function updateTransition(dt)
if not trans then
mode = "free"
return
end
trans.t += dt
local u = math.min(trans.t / trans.duration, 1)
local eased = smoothstep(u)
local out = {}
for channel = 1, 7 do
out[channel] = trans.from[channel] + (trans.to[channel] - trans.from[channel]) * eased
end
applyChannels(out)
if u >= 1 then
local callback = trans.onDone
trans = nil
mode = "free"
velocity = Vector3.zero
if callback then
callback()
end
refreshStatus()
end
end
local function updatePath(dt)
local count = #keyframes
if count < 2 then
mode = "free"
refreshStatus()
return
end
pathT += dt
local u = pathT / pathDuration
local finished = false
if u >= 1 then
if pathLoop then
pathT = pathT % pathDuration
u = pathT / pathDuration
else
u = 1
finished = true
end
end
pathProgress = u
local eased = pathSmooth and smoothstep(u) or u
local segment = eased * (count - 1)
local index = math.min(math.floor(segment) + 1, count - 1)
local t = segment - (index - 1)
local k0 = keyframes[math.max(index - 1, 1)]
local k1 = keyframes[index]
local k2 = keyframes[index + 1]
local k3 = keyframes[math.min(index + 2, count)]
local out = {}
for channel = 1, 7 do
out[channel] = catmull(k0[channel], k1[channel], k2[channel], k3[channel], t)
end
applyChannels(out)
if finished then
mode = "free"
velocity = Vector3.zero
refreshStatus()
end
end
function stopAutomation()
if mode == "path" or mode == "goto" then
trans = nil
mode = "free"
velocity = Vector3.zero
refreshStatus()
end
end
function addKeyframe()
if not active then
notify("n_activate")
return
end
if mode == "path" or mode == "goto" then
notify("n_stoppath")
return
end
local keyframe = captureKeyframe()
local previous = keyframes[#keyframes]
if previous then
keyframe[4] = previous[4] + angleDiff(previous[4], keyframe[4])
end
table.insert(keyframes, keyframe)
ui.refreshPathLabel()
notify("n_point", #keyframes)
end
function clearPath()
stopAutomation()
keyframes = {}
ui.refreshPathLabel()
notify("n_cleared")
end
function startPath()
if not active then
notify("n_activate")
return
end
if #keyframes < 2 then
notify("n_min2")
return
end
if mode == "spectate" then
exitSpectate()
end
beginTransition(keyframes[1], TRANSITION_TIME, function()
pathT = 0
pathProgress = 0
mode = "path"
end)
end
function togglePath()
if pathIsPlaying() then
stopAutomation()
notify("n_pathstop")
else
startPath()
end
end
function saveSlot(index)
if not active then
notify("n_activate")
return
end
if mode == "path" or mode == "goto" then
notify("n_stoppath")
return
end
slots[index] = captureKeyframe()
refreshSlotButtons()
notify("n_saved", index)
end
function gotoSlot(index)
local slot = slots[index]
if not slot then
notify("n_slotempty", index)
return
end
if not active then
setFreecam(true)
if not active then return end
end
if mode == "spectate" then
exitSpectate()
end
if mode == "path" or mode == "goto" then
stopAutomation()
end
beginTransition(slot, TRANSITION_TIME)
end
local function listOthers()
local list = {}
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player then
table.insert(list, p)
end
end
table.sort(list, function(a, b)
return a.Name:lower() < b.Name:lower()
end)
return list
end
function startSpectate(target)
if not target or target == player then return end
if not active then
setFreecam(true)
if not active then return end
end
if mode == "path" or mode == "goto" then
stopAutomation()
end
releaseLook()
mode = "spectate"
specTarget = target
specLastPos = nil
streamLastPos = nil
specFPCF = nil
specFocus = nil
velocity = Vector3.zero
local character = target.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if root then
local look = root.CFrame.LookVector
local startYaw = math.atan2(-look.X, -look.Z)
yaw = startYaw
targetYaw = startYaw
pitch = math.rad(-12)
targetPitch = pitch
specFocus = root.Position + Vector3.new(0, 1.5, 0)
end
refreshStatus()
end
function exitSpectate()
if mode ~= "spectate" then return end
mode = "free"
specTarget = nil
specFPCF = nil
specFocus = nil
local cf = lastCF or (camera and camera.CFrame) or CFrame.new(position)
local newYaw, newPitch = anglesFromLook(cf.LookVector)
position = cf.Position
yaw = newYaw
pitch = math.clamp(newPitch, math.rad(-85), math.rad(85))
targetYaw = yaw
targetPitch = pitch
velocity = Vector3.zero
refreshStatus()
end
function cycleSpectate(direction)
local list = listOthers()
if #list == 0 then
notify("n_noplayers")
return
end
local index = 0
for i, p in ipairs(list) do
if p == specTarget then
index = i
break
end
end
if index == 0 then
index = direction > 0 and 1 or #list
else
index = ((index - 1 + direction) % #list) + 1
end
startSpectate(list[index])
end
function toggleSpectate()
if mode == "spectate" then
exitSpectate()
else
cycleSpectate(1)
end
end
function teleportToCamera()
if not active then
notify("n_activate")
return
end
if mode == "spectate" then
notify("n_exitspect")
return
end
local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not (character and root) then
notify("n_nochar")
return
end
if humanoid and humanoid.SeatPart then
humanoid.Sit = false
task.wait()
end
local targetCFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
local ok = pcall(function()
character:PivotTo(targetCFrame)
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end)
notify(ok and "n_tp" or "n_failed")
end
function cameraToCharacter()
if not active then
notify("n_activate")
return
end
local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if not root then
notify("n_nochar")
return
end
if mode == "spectate" then
exitSpectate()
end
if mode == "path" or mode == "goto" then
stopAutomation()
end
local focus = root.Position + Vector3.new(0, 2, 0)
local cameraPosition = focus - root.CFrame.LookVector * 10 + Vector3.new(0, 3, 0)
local direction = (focus - cameraPosition).Unit
local newYaw, newPitch = anglesFromLook(direction)
beginTransition(
{ cameraPosition.X, cameraPosition.Y, cameraPosition.Z, newYaw, newPitch, 0, currentFOV },
TRANSITION_TIME
)
end
function setFreecam(enabled)
if active == enabled then return end
camera = workspace.CurrentCamera
if not camera then return end
if enabled then
oldCameraType = camera.CameraType
oldCameraSubject = camera.CameraSubject
oldFOV = camera.FieldOfView
oldMouseBehavior = UIS.MouseBehavior
oldMouseIconEnabled = UIS.MouseIconEnabled
position = camera.CFrame.Position
velocity = Vector3.zero
yaw, pitch = anglesFromLook(camera.CFrame.LookVector)
roll = 0
targetYaw = yaw
targetPitch = pitch
targetRoll = 0
currentFOV = camera.FieldOfView
targetFOV = currentFOV
mode = "free"
trans = nil
specTarget = nil
lastCF = camera.CFrame
active = true
hideGameHUD()
bindInput()
if hideSelf then
applyHideSelf(true)
end
camera.CameraType = Enum.CameraType.Scriptable
ui.fovSlider.set(targetFOV, true)
ui.rollSlider.set(0, true)
else
active = false
mode = "free"
trans = nil
specTarget = nil
specFocus = nil
specFPCF = nil
releaseLook()
restoreGameHUD()
unbindInput()
applyHideSelf(false)
camera.CameraType = oldCameraType or Enum.CameraType.Custom
if oldCameraSubject then
camera.CameraSubject = oldCameraSubject
end
if oldFOV then
camera.FieldOfView = oldFOV
end
UIS.MouseBehavior = oldMouseBehavior or Enum.MouseBehavior.Default
UIS.MouseIconEnabled = oldMouseIconEnabled ~= false
velocity = Vector3.zero
end
refreshStatus()
end
table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
if input.KeyCode == HIDE_MENU_KEY then
gui.Enabled = not gui.Enabled
return
end
if active
and input.UserInputType == Enum.UserInputType.MouseButton2
and (mode == "free" or mode == "spectate") then
lookHeld = true
UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
UIS.MouseIconEnabled = false
return
end
if processed then return end
if UIS:GetFocusedTextBox() then return end
if input.KeyCode == TOGGLE_KEY then
setFreecam(not active)
end
end))
table.insert(connections, UIS.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton2 then
releaseLook()
end
end))
table.insert(connections, UIS.InputChanged:Connect(function(input, processed)
if not active or processed then return end
if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
local direction = input.Position.Z
if mode == "spectate" then
specDist = math.clamp(specDist - direction * 2, 3, 60)
ui.distSlider.set(specDist, true)
elseif ctrlDown() then
baseSpeed = math.clamp(baseSpeed + direction * 5, 5, 150)
ui.speedSlider.set(baseSpeed, true)
elseif mode == "free" then
targetFOV = math.clamp(targetFOV - direction * ZOOM_STEP, MIN_FOV, MAX_FOV)
ui.fovSlider.set(targetFOV, true)
end
end))
table.insert(connections, RunService.RenderStepped:Connect(function(dt)
if not active then return end
camera = workspace.CurrentCamera
if not camera then return end
local typing = UIS:GetFocusedTextBox() ~= nil
if lookHeld and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
releaseLook()
end
if mode == "path" then
updatePath(dt)
elseif mode == "goto" then
updateTransition(dt)
end
local automated = mode == "path" or mode == "goto"
if not automated then
if lookHeld then
UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
local delta = UIS:GetMouseDelta()
targetYaw = targetYaw - delta.X * SENSITIVITY
targetPitch = math.clamp(
targetPitch - delta.Y * SENSITIVITY,
math.rad(-85),
math.rad(85)
)
elseif mode == "spectate" and specMode == 2 then
targetYaw = targetYaw + orbitSpeed * dt
end
if not typing then
local rollStep = math.rad(ROLL_SPEED_DEG) * dt
local limit = math.rad(MAX_ROLL_DEG)
if isDown(Enum.KeyCode.Z) then
targetRoll = math.clamp(targetRoll - rollStep, -limit, limit)
end
if isDown(Enum.KeyCode.C) then
targetRoll = math.clamp(targetRoll + rollStep, -limit, limit)
end
end
local rotationAlpha = 1 - math.exp(-ROTATION_SMOOTH * dt)
yaw = smoothAngle(yaw, targetYaw, rotationAlpha)
pitch = pitch + (targetPitch - pitch) * rotationAlpha
roll = roll + (targetRoll - roll) * rotationAlpha
end
local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
local baseCF
if mode == "free" then
local direction = Vector3.zero
if not typing then
if isDown(Enum.KeyCode.W) then
direction += rotation.LookVector
end
if isDown(Enum.KeyCode.S) then
direction -= rotation.LookVector
end
if isDown(Enum.KeyCode.D) then
direction += rotation.RightVector
end
if isDown(Enum.KeyCode.A) then
direction -= rotation.RightVector
end
if isDown(Enum.KeyCode.E) then
direction += Vector3.yAxis
end
if isDown(Enum.KeyCode.Q) then
direction -= Vector3.yAxis
end
end
if direction.Magnitude > 0 then
direction = direction.Unit
end
local slow = not typing and isDown(Enum.KeyCode.LeftShift)
local fast = not typing and isDown(Enum.KeyCode.Space)
local speed = baseSpeed
local label = "NORMAL"
if fast and not slow then
speed = baseSpeed * FAST_MULT
label = "RÁPIDO"
elseif slow and not fast then
speed = baseSpeed * SLOW_MULT
label = "LENTO"
end
currentSpeedMode = label
currentSpeedValue = speed
local desiredVelocity = direction * speed
local response = direction.Magnitude > 0
and ACCELERATION
or DECELERATION
local movementAlpha = 1 - math.exp(-response * dt)
velocity = velocity:Lerp(desiredVelocity, movementAlpha)
position += velocity * dt
elseif mode == "spectate" then
velocity = Vector3.zero
local target = specTarget
if not target or target.Parent ~= Players then
exitSpectate()
notify("n_playerleft")
else
local character = target.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local head = character and character:FindFirstChild("Head")
if root then
local raw = root.Position + Vector3.new(0, 1.5, 0)
if specFocus then
specFocus = specFocus:Lerp(raw, 1 - math.exp(-14 * dt))
else
specFocus = raw
end
end
if specMode == 3 and (head or root) then
local source = head or root
local firstPerson = source.CFrame * CFrame.new(0, 0.15, -0.6)
if specFPCF then
specFPCF = specFPCF:Lerp(firstPerson, 1 - math.exp(-20 * dt))
else
specFPCF = firstPerson
end
baseCF = specFPCF
position = baseCF.Position
elseif specFocus then
position = specFocus - rotation.LookVector * specDist
baseCF = CFrame.new(position) * rotation * CFrame.Angles(0, 0, roll)
end
end
else
velocity = Vector3.zero
end
baseCF = baseCF or (CFrame.new(position) * rotation * CFrame.Angles(0, 0, roll))
lastCF = baseCF
if not automated then
local zoomAlpha = 1 - math.exp(-ZOOM_SMOOTH * dt)
currentFOV = currentFOV + (targetFOV - currentFOV) * zoomAlpha
end
camera.FieldOfView = currentFOV
local finalCF = baseCF
if shakeAmount > 0 then
local t = os.clock()
local a = shakeAmount
local offset = Vector3.new(
math.noise(t * 7, 0, 11),
math.noise(0, t * 7, 23),
math.noise(t * 5, t * 5, 37)
) * 0.4 * a
local tilt = CFrame.Angles(
math.noise(t * 6, 5, 0) * 0.05 * a,
math.noise(7, t * 6, 0) * 0.05 * a,
math.noise(0, 9, t * 6) * 0.04 * a
)
finalCF = baseCF * CFrame.new(offset) * tilt
end
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = finalCF
camera.Focus = finalCF
streamTick()
if hideSelf then
hideTimer += dt
if hideTimer > 0.3 then
hideTimer = 0
applyHideSelf(true)
end
end
syncTimer += dt
if syncTimer > 0.1 then
syncTimer = 0
if not activeSlider then
ui.fovSlider.set(targetFOV, true)
ui.rollSlider.set(math.deg(targetRoll), true)
end
refreshStatus()
end
end))
for _, p in ipairs(Players:GetPlayers()) do
ui.addPlayerButton(p)
end
table.insert(connections, Players.PlayerAdded:Connect(ui.addPlayerButton))
table.insert(connections, Players.PlayerRemoving:Connect(ui.removePlayerButton))
env.CAMHUB_FREECAM_CLEANUP = function()
if active then
setFreecam(false)
else
restoreGameHUD()
unbindInput()
end
for _, connection in ipairs(connections) do
pcall(function()
connection:Disconnect()
end)
end
for _, effect in pairs(fx) do
pcall(function()
effect:Destroy()
end)
end
pcall(function()
gui:Destroy()
end)
pcall(function()
fxGui:Destroy()
end)
print("[CamHub] FREECAM STUDIO LIMPA")
end
K.setTheme(K.theme)
K.setLang(K.lang)
ui.refreshSpecModeButtons()
ui.refreshPathLabel()
refreshSlotButtons()
ui.showTab(1)
refreshStatus()
print("[CamHub] XENO FREECAM STUDIO v4.0 CARREGADA")
