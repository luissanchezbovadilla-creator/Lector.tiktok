require "import"
import "android.os.Handler"
import "android.os.Looper"
import "android.os.Bundle"
import "android.graphics.Rect"
import "android.speech.tts.TextToSpeech"
import "android.media.AudioAttributes"
import "android.app.AlertDialog"
import "android.widget.LinearLayout"
import "android.widget.ScrollView"
import "android.widget.TextView"
import "android.widget.EditText"
import "android.widget.CheckBox"
import "android.widget.Button"
import "android.widget.SeekBar"
import "android.view.WindowManager"
import "android.media.MediaPlayer"
import "android.media.SoundPool"
import "java.io.File"
import "java.io.FileOutputStream"
import "java.io.FileInputStream"
import "java.net.URL"
import "java.lang.Thread"
import "java.lang.Runnable"
import "java.util.zip.ZipInputStream"
import "android.os.Environment"
import "java.util.Locale"
import "java.lang.String"
import "android.graphics.Color"
import "android.graphics.drawable.GradientDrawable"
import "android.view.Gravity"
import "android.content.Intent"
import "android.net.Uri"
import "android.content.DialogInterface"

-- ==========================================
-- SISTEMA DE ACTUALIZACIÓN AUTOMÁTICA Y MANUAL
-- ==========================================
local VERSION_ACTUAL = 3.0
-- Enlaces en su forma más pura y corta
local URL_VERSION = "https://gist.githubusercontent.com/luissanchezbovadilla-creator/56180ab6787ac7a22af396a07ace9f34/raw" 
local URL_CODIGO = "https://gist.githubusercontent.com/luissanchezbovadilla-creator/41599bcb45dcad7a61870cec814e6cbc/raw"

local function comprobarActualizacion(modoManual)
    Thread(Runnable({
        run = function()
            local exito, err = pcall(function()
                local conexion = URL(URL_VERSION).openConnection()
                conexion.setConnectTimeout(5000)
                conexion.setReadTimeout(5000)
                conexion.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                
                local is = conexion.getInputStream()
                local scanner = java.util.Scanner(is).useDelimiter("\\A")
                local versionRemotaStr = scanner.hasNext() and scanner.next() or ""
                is.close()
                
                local versionRemota = tonumber(versionRemotaStr:match("^%s*(.-)%s*$"))
                
                if versionRemota and versionRemota > VERSION_ACTUAL then
                    Handler(Looper.getMainLooper()).post(Runnable({
                        run = function()
                            service.speak("Nueva versión " .. versionRemota .. " encontrada. Descargando actualización...")
                        end
                    }))
                    
                    local conCodigo = URL(URL_CODIGO).openConnection()
                    conCodigo.setConnectTimeout(15000)
                    conCodigo.setReadTimeout(15000)
                    conCodigo.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                    
                    local isCodigo = conCodigo.getInputStream()
                    
                    local rutaActual = ""
                    pcall(function() rutaActual = debug.getinfo(1, "S").source:match("^@?(.*)") end)
                    
                    local guardado = false
                    if rutaActual and rutaActual ~= "" then
                        local fDestino = File(rutaActual)
                        if fDestino.exists() then
                            local fos = FileOutputStream(fDestino)
                            local buffer = byte[4096]
                            local leido = isCodigo.read(buffer)
                            while leido > 0 do
                                fos.write(buffer, 0, leido)
                                leido = isCodigo.read(buffer)
                            end
                            fos.close()
                            guardado = true
                        end
                    end
                    
                    if not guardado then
                        local rutaDestino = Environment.getExternalStorageDirectory().getAbsolutePath() .. "/jieshuo/plugins/Lector TikTok Pro.lua"
                        local fFallback = File(rutaDestino)
                        if fFallback.getParentFile().exists() then
                            local fos = FileOutputStream(fFallback)
                            local buffer = byte[4096]
                            local leido = isCodigo.read(buffer)
                            while leido > 0 do
                                fos.write(buffer, 0, leido)
                                leido = isCodigo.read(buffer)
                            end
                            fos.close()
                        end
                    end
                    isCodigo.close()
                    
                    Handler(Looper.getMainLooper()).post(Runnable({
                        run = function()
                            service.speak("¡Plugin actualizado con éxito a la versión " .. versionRemota .. "! Apágalo y vuelve a encenderlo para aplicar los cambios.")
                        end
                    }))
                else
                    if modoManual then
                        Handler(Looper.getMainLooper()).post(Runnable({
                            run = function()
                                service.speak("Ya tienes la versión más reciente, versión " .. VERSION_ACTUAL .. ".")
                            end
                        }))
                    end
                end
            end)
            
            -- SISTEMA INTELIGENTE DE ERRORES PARA DETECTAR ENLACES ROTOS
            if not exito and modoManual then
                local msjError = "Error desconocido."
                local errorReal = tostring(err)
                
                if errorReal:find("FileNotFoundException") then
                    msjError = "Error 404. El enlace de Gist está roto o el archivo fue borrado."
                elseif errorReal:find("UnknownHostException") then
                    msjError = "No hay conexión a internet para verificar."
                else
                    msjError = "Error de red al conectar con el servidor."
                end
                
                Handler(Looper.getMainLooper()).post(Runnable({
                    run = function()
                        service.speak(msjError)
                    end
                }))
            end
        end
    })).start()
end

if not _G.LSTikTokReader then
    _G.LSTikTokReader = {
        activo = false,
        pausado = false,
        recienIniciado = false,
        tts = nil,
        handler = Handler(Looper.getMainLooper()),
        runnable = nil,
        config = {},
        historialHash = {},
        historialArray = {},
        indiceHistorial = 1,
        limiteHistorial = 50 
    }
end

local AppState = _G.LSTikTokReader
local pref = service.getSharedPreferences("TikTokLectorConfig", 0)

-- ==========================================
-- FILTRO BASE DE PROTECCIÓN
-- ==========================================
local defaultFiltro = "mongolo|mongolito|descuartizar|descuartizador|mongola|maricon|negro|cabro|violador|asesino|sicario|veneca|veneco"

local fechaExpiracion = os.time({year=2026, month=12, day=31, hour=23, min=59, sec=59})
if os.time() > fechaExpiracion then
    service.speak("Esta versión ha expirado. Por favor, contacta a LS Accesible.")
    return true
end

-- ==========================================
-- DISEÑO UI: ELEGANTE
-- ==========================================
local colorFondoApp = "#000000"
local colorTextoBlanco = "#FFFFFF"
local colorFondoRojo = "#D32F2F"

local function aplicarEstiloTexto(lbl)
    lbl.setTextColor(Color.parseColor(colorTextoBlanco))
    lbl.setTextSize(16)
end

local function aplicarEstiloLayout(layout)
    layout.setBackgroundColor(Color.parseColor(colorFondoApp))
    layout.setPadding(50, 50, 50, 50)
end

local function crearBotonPersonalizado(texto, accionOnClick, esAccionPrincipal)
    local btn = Button(service)
    btn.setText(texto)
    local shape = GradientDrawable()
    shape.setShape(GradientDrawable.RECTANGLE)
    shape.setCornerRadius(30)
    if esAccionPrincipal then
        shape.setColor(Color.parseColor(colorFondoRojo))
        shape.setStroke(3, Color.parseColor(colorFondoRojo))
    else
        shape.setColor(Color.parseColor(colorFondoApp))
        shape.setStroke(3, Color.parseColor(colorTextoBlanco))
    end
    btn.setBackgroundDrawable(shape)
    btn.setTextColor(Color.parseColor(colorTextoBlanco))
    btn.setGravity(Gravity.CENTER)
    local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    params.setMargins(0, 15, 0, 15)
    btn.setLayoutParams(params)
    btn.setPadding(0, 30, 0, 30)
    if accionOnClick then btn.onClick = accionOnClick end
    return btn
end

local function eliminarCarpetaRecursivamente(fileOrDir)
    if fileOrDir.isDirectory() then
        local hijos = fileOrDir.listFiles()
        if hijos then for i = 0, #hijos - 1 do eliminarCarpetaRecursivamente(hijos[i]) end end
    end
    fileOrDir.delete()
end

-- ==========================================
-- DESCARGA BLINDADA
-- ==========================================
local function descargarPaqueteSonidos()
    local carpetaDestino = Environment.getExternalStorageDirectory().getAbsolutePath() .. "/LSTikTok_Sonidos"
    local dir = File(carpetaDestino)
    
    if dir.exists() and dir.isDirectory() then
        local archivos = dir.listFiles()
        if archivos and #archivos > 10 then
            service.speak("El paquete de sonidos ya está instalado en tu dispositivo.")
            return
        end
    end

    service.speak("Descargando y organizando audios. Por favor espera unos minutos.")

    Thread(Runnable({
        run = function()
            local exitoDescarga = false
            local archivoTmp = carpetaDestino .. "/temp_paquete.zip"
            
            pcall(function()
                if not dir.exists() then dir.mkdirs() end
                
                local urlEnlace = "https://drive.google.com/uc?export=download&id=1OKvPPe10MGU99ep3VUfLPQCebeiSaes2"
                local conexion = URL(urlEnlace).openConnection()
                conexion.setConnectTimeout(15000)
                conexion.setReadTimeout(60000)
                
                local is = conexion.getInputStream()
                local fos = FileOutputStream(archivoTmp)
                local buffer = byte[4096]
                local leido = is.read(buffer)
                while leido > 0 do
                    fos.write(buffer, 0, leido)
                    leido = is.read(buffer)
                end
                fos.close()
                is.close()
                
                local tmpFile = File(archivoTmp)
                if tmpFile.exists() and tmpFile.length() > 50000 then 
                    exitoDescarga = true
                end
            end)

            if exitoDescarga then
                local exitoExtraccion = pcall(function()
                    local hijos = dir.listFiles()
                    if hijos then
                        for i = 0, #hijos - 1 do
                            if hijos[i].getName() ~= "temp_paquete.zip" then eliminarCarpetaRecursivamente(hijos[i]) end
                        end
                    end
                    
                    local zis = ZipInputStream(FileInputStream(archivoTmp))
                    local entrada = zis.getNextEntry()
                    local buffer = byte[4096]
                    while entrada ~= nil do
                        if not entrada.isDirectory() then
                            local nombreOriginal = entrada.getName()
                            local nombreArchivoLimpio = nombreOriginal:match("([^/]+)$") or nombreOriginal
                            if nombreArchivoLimpio ~= "" and not string.match(nombreArchivoLimpio, "^%.") then
                                local fos = FileOutputStream(File(carpetaDestino, nombreArchivoLimpio))
                                local leido = zis.read(buffer)
                                while leido > 0 do fos.write(buffer, 0, leido); leido = zis.read(buffer) end
                                fos.close()
                            end
                        end
                        zis.closeEntry()
                        entrada = zis.getNextEntry()
                    end
                    zis.close()
                end)
                
                File(archivoTmp).delete()
                
                Handler(Looper.getMainLooper()).post(Runnable({
                    run = function()
                        if exitoExtraccion then service.speak("¡Paquete instalado con éxito!")
                        else service.speak("Error al extraer los archivos.") end
                    end
                }))
            else
                File(archivoTmp).delete()
                Handler(Looper.getMainLooper()).post(Runnable({
                    run = function() service.speak("Error de red. No se pudo descargar el paquete.") end
                }))
            end
        end
    })).start()
end

-- ==========================================
-- MÓDULO DE AUDIO SEGURO
-- ==========================================
local AudioEngine = { pool = nil, sonidos = {}, listos = {} }

function AudioEngine.cargarSonidos(config)
    if AudioEngine.pool then pcall(function() AudioEngine.pool.release() end) end
    
    local tipoCanal = 3 
    local exitoPool = pcall(function() AudioEngine.pool = SoundPool(6, tipoCanal, 0) end)
    if not exitoPool or not AudioEngine.pool then AudioEngine.pool = SoundPool(6, 3, 0) end

    AudioEngine.sonidos = {}
    AudioEngine.listos = {}

    AudioEngine.pool.setOnLoadCompleteListener(SoundPool.OnLoadCompleteListener({
        onLoadComplete = function(soundPool, sampleId, status)
            if status == 0 then AudioEngine.listos[sampleId] = true end
        end
    }))

    local function cargar(ruta)
        if ruta and ruta ~= "" then
            local f = File(ruta)
            if f.exists() and f.canRead() then return AudioEngine.pool.load(ruta, 1) end
        end
        return nil
    end
    AudioEngine.sonidos.uniones = cargar(config.sndUniones)
    AudioEngine.sonidos.likes = cargar(config.sndLikes)
    AudioEngine.sonidos.compartidas = cargar(config.sndCompartidas)
    AudioEngine.sonidos.seguidores = cargar(config.sndSeguidores)
    AudioEngine.sonidos.regalos = cargar(config.sndRegalos)
    AudioEngine.sonidos.filtro = cargar(config.sndFiltro)
end

local mediaPlayerActual = nil
function AudioEngine.alternarReproduccionMuestra(ruta)
    if not ruta or ruta == "" then return end
    pcall(function()
        if mediaPlayerActual then
            if mediaPlayerActual.isPlaying() then
                mediaPlayerActual.stop()
                mediaPlayerActual.release()
                mediaPlayerActual = nil
                return
            else
                mediaPlayerActual.release()
                mediaPlayerActual = nil
            end
        end
        
        mediaPlayerActual = MediaPlayer()
        mediaPlayerActual.setDataSource(ruta)
        mediaPlayerActual.setAudioStreamType(3)
        mediaPlayerActual.setOnPreparedListener(MediaPlayer.OnPreparedListener({
            onPrepared = function(mp) mp.start() end
        }))
        mediaPlayerActual.setOnCompletionListener(MediaPlayer.OnCompletionListener({
            onCompletion = function(m) pcall(function() m.release(); mediaPlayerActual = nil end) end
        }))
        mediaPlayerActual.prepareAsync()
    end)
end

function AudioEngine.detenerReproductorActual()
    pcall(function()
        if mediaPlayerActual then
            if mediaPlayerActual.isPlaying() then mediaPlayerActual.stop() end
            mediaPlayerActual.release()
            mediaPlayerActual = nil
        end
    end)
end

function AudioEngine.hablar(texto, modo)
    if AppState.tts and texto and texto ~= "" then
        local m = modo or 1
        pcall(function() AppState.tts.speak(texto, m, nil, "LS_TTS_ID") end)
    end
end

-- ==========================================
-- NORMALIZACIÓN Y ESCÁNER
-- ==========================================
local function normalizarTextoFuerte(texto)
    if not texto or tostring(texto) == "" then return "" end
    local exito, jStr = pcall(function() return String(texto):toLowerCase(Locale.getDefault()) end)
    if not exito then return string.lower(tostring(texto)) end
    
    jStr = jStr:replaceAll("[áàâäã]", "a")
    jStr = jStr:replaceAll("[éèêë]", "e")
    jStr = jStr:replaceAll("[íìîï]", "i")
    jStr = jStr:replaceAll("[óòôöõ]", "o")
    jStr = jStr:replaceAll("[úùûü]", "u")
    
    local str = tostring(jStr)
    str = string.gsub(str, "[%s%p%c]", "")
    str = string.gsub(str, "(.)%1+", "%1")
    return str
end

local Scanner = {
    rectCache = Rect(), limiteSuperiorY = 0, limiteInferiorY = 0, pantallaConfigurada = false,
    lecturasPendientes = {}, cajasProcesadas = {}, palabrasProhibidas = {},
    paquetesSilenciosos = { [""]=true, ["com.android.systemui"]=true, ["com.miui.systemui"]=true, ["com.google.android.inputmethod.latin"]=true, ["com.facemoji.lite.xiaomi"]=true, ["com.facemoji.lite"]=true, ["com.touchtype.swiftkey"]=true, ["com.samsung.android.honeyboard"]=true },
    botonesInterfaz = { ["ánimo"]=true, ["animo"]=true, ["aplausos"]=true, ["risa"]=true, ["beso"]=true, ["boing"]=true, ["latidos"]=true, ["guau"]=true, ["grito"]=true, ["silbato"]=true, ["tambor"]=true, ["compartir"]=true, ["regalo"]=true, ["compartirvideo"]=true, ["escribealgo"]=true, ["añadircomentario"]=true, ["dialgo"]=true, ["rosa"]=true, ["exclusivo"]=true, ["recargar"]=true, ["enviar"]=true, ["invitar"]=true, ["mejorar"]=true, ["efectos"]=true, ["stickers"]=true, ["música"]=true, ["fondo"]=true, ["paneles"]=true, ["guía"]=true, ["activarelmicrófono"]=true, ["desactivarelmicrófono"]=true, ["anillosdevoz"]=true, ["desconectar"]=true, ["aceptar"]=true, ["rechazar"]=true, ["cancelarsolicitud"]=true, ["unirse"]=true, ["dejarunmensaje"]=true, ["cancelar"]=true, ["iniciar"]=true, ["agregarcomoinvitado"]=true, ["responder"]=true, ["traducir"]=true, ["vertraducción"]=true, ["vertraduccion"]=true, ["fijar"]=true, ["fijado"]=true, ["responderalcomentario"]=true, ["denunciar"]=true, ["silenciar"]=true, ["bloquear"]=true, ["copiar"]=true, ["anclar"]=true },
    panelesBloqueo = { ["copiar enlace"]=true, ["whatsapp"]=true, ["messenger"]=true, ["sms"]=true, ["reportar"]=true, ["denunciar"]=true, ["enviar a"]=true, ["cancelar"]=true, ["clasificaciones de espectadores"]=true, ["principales espectadores"]=true, ["regalos más populares"]=true, ["envía un regalo"]=true, ["misión del club de fans"]=true, ["recargar"]=true, ["regalos live"]=true, ["momentos destacados del live"]=true, ["eliminar ruido de fondo"]=true, ["ajustes"]=true, ["efectos de voz"]=true, ["efectos de sonido"]=true, ["emitir live con invitados"]=true, ["amigos que no miran este live"]=true, ["invitaciones rápidas"]=true, ["creadores recomendados"]=true, ["cofre del tesoro"]=true, ["bolsa de obsequios"]=true, ["cofre de superfan"]=true, ["encuesta y votar"]=true, ["dibuja y adivina"]=true, ["preguntas y respuestas"]=true, ["fondo de pantalla de ia"]=true, ["favorito del público"]=true, ["canciones de live"]=true, ["sé una leyenda"]=true, ["batallas de las ligas"]=true, ["solicitud de invitado enviada"]=true, ["te invita a unirte"]=true, ["tus invitaciones y solicitudes"]=true, ["hay otras"]=true, ["no quieres esperar"]=true, ["encuentra un live"]=true, ["total de visualizaciones"]=true, ["live restringido"]=true, ["tu live se restringió"]=true, ["tus diamantes y recompensas"]=true, ["trayectoria live"]=true },
    bloqueadoresGlobales = { ["inicio"]=true, ["bandeja de entrada"]=true, ["perfil"]=true, ["amigos"]=true, ["para ti"]=true, ["siguiendo"]=true, ["enviar mensaje"]=true, ["mensajes directos"]=true }
}

function Scanner.prepararFiltros()
    Scanner.palabrasProhibidas = {}
    if AppState.config.filtro ~= "" then
        for w in string.gmatch(AppState.config.filtro, "([^|]+)") do
            local palabraLimpia = normalizarTextoFuerte(w)
            if palabraLimpia ~= "" then Scanner.palabrasProhibidas[palabraLimpia] = true end
        end
    end
end

function Scanner.esDuplicado(textoNormalizado)
    if not textoNormalizado or textoNormalizado == "" then return true end
    return AppState.historialHash[textoNormalizado] == true
end

function Scanner.registrarHistorial(textoNormalizado)
    local idx = AppState.indiceHistorial
    local antiguo = AppState.historialArray[idx]
    if antiguo then AppState.historialHash[antiguo] = nil end
    AppState.historialArray[idx] = textoNormalizado
    AppState.historialHash[textoNormalizado] = true
    AppState.indiceHistorial = (idx % AppState.limiteHistorial) + 1
end

function Scanner.reducirSpam(texto)
    local exito, res = pcall(function() return tostring(String(texto):replaceAll("(?i)(.+?)\\1{3,}", "$1$1$1")) end)
    return exito and res or texto
end

function Scanner.esBotonDinamico(txtLower, txtNorm)
    if Scanner.botonesInterfaz[txtNorm] then return true end
    if txtLower:find("vez compartido") or txtLower:find("veces compartido") or txtLower:find("compartir video") then return true end
    if txtLower:find("a unirse como invitado") or txtLower:find("invita a") then return true end
    if txtLower:find("espectadores enviaron una solicitud") then return true end
    return false
end

function Scanner.extraerContenedor(nodoFila)
    local textos = {}
    local function recolectar(n)
        if not n or not n.isVisibleToUser() then return end
        if n.isEditable() or (n.getClassName() and tostring(n.getClassName()):find("EditText")) then return end
        
        local txtOriginal = n.getText()
        if not txtOriginal or tostring(txtOriginal) == "" then
            txtOriginal = n.getContentDescription()
        end
        
        if txtOriginal and tostring(txtOriginal) ~= "" then
            local s = tostring(txtOriginal):match("^%s*(.-)%s*$")
            if s ~= "" then
                local sLower = s:lower()
                local esRuido = false
                if #s == 1 then esRuido = true end
                if s:match("^N[°º%.%-]?%d+$") then esRuido = true end
                if sLower:match("^nivel %d+") or sLower:find("insignia", 1, true) or sLower:find("top espectador", 1, true) or sLower == "creador" then esRuido = true end
                if Scanner.botonesInterfaz[sLower:gsub("[%s%p]", "")] then esRuido = true end
                
                if not esRuido then 
                    if #textos == 0 or textos[#textos]:lower() ~= sLower then table.insert(textos, s) end
                end
            end
        end
        local count = n.getChildCount()
        if count then for i = 0, count - 1 do recolectar(n.getChild(i)) end end
    end
    recolectar(nodoFila)

    if #textos > 4 or #textos == 0 then return "" end
    if #textos >= 2 and textos[1] ~= textos[2] then
        local usuario = textos[1]
        local msj = table.concat(textos, " ", 2)
        if msj == "" then return "" end
        if AppState.config.leerConDice then return usuario .. " dice: " .. msj else return usuario .. ": " .. msj end
    elseif #textos == 1 then
        local t = textos[1]:lower()
        if t:find("se unió") or t:find("joined") or t:find("me gusta") or t:find("compartió") or t:find("siguió") or t:find("envió") then return textos[1] end
        return ""
    end
    return ""
end

function Scanner.ejecutarCiclo()
    if not AppState.activo then return end

    local exito, root = pcall(function() return service.getRootInActiveWindow() end)
    if not exito or not root then
        if AppState.activo then AppState.handler.postDelayed(AppState.runnable, 400) end
        return
    end

    local paquete = tostring(root.getPackageName() or "")
    if Scanner.paquetesSilenciosos[paquete] then
        if AppState.activo then AppState.handler.postDelayed(AppState.runnable, 400) end
        return
    end

    if paquete ~= "com.zhiliaoapp.musically" and paquete ~= "com.ss.android.ugc.trill" then
        if not AppState.pausado then
            AppState.pausado = true
            local modoPausa = AppState.recienIniciado and 1 or 0
            AudioEngine.hablar("Lector pausado.", modoPausa)
        end
        AppState.recienIniciado = false
        AppState.handler.postDelayed(AppState.runnable, 1000)
        return
    end

    if not Scanner.pantallaConfigurada then
        root.getBoundsInScreen(Scanner.rectCache)
        Scanner.limiteSuperiorY = math.floor(Scanner.rectCache.bottom * 0.52)
        Scanner.limiteInferiorY = math.floor(Scanner.rectCache.bottom * 0.95)
        Scanner.pantallaConfigurada = true
    end

    Scanner.lecturasPendientes = {}
    Scanner.cajasProcesadas = {}
    local panelAbierto = false
    local esEntornoValido = true

    pcall(function()
        local function explorar(nodo)
            if not nodo or panelAbierto or not esEntornoValido then return end
            if not nodo.isVisibleToUser() then return end

            local txtInfo = nodo.getText()
            if not txtInfo or tostring(txtInfo) == "" then txtInfo = nodo.getContentDescription() end
            
            if txtInfo and tostring(txtInfo) ~= "" then
                local tOriginal = tostring(txtInfo)
                local tLower = tOriginal:lower():match("^%s*(.-)%s*$")
                
                if tLower then
                    if Scanner.bloqueadoresGlobales[tLower] then esEntornoValido = false return end
                    
                    local tNorm = tLower:gsub("[%s%p]", "")
                    if Scanner.panelesBloqueo[tLower] or Scanner.panelesBloqueo[tNorm] or tLower:find("regalos más populares") or tLower:find("clasificaciones de") then panelAbierto = true return end
                    
                    nodo.getBoundsInScreen(Scanner.rectCache)
                    
                    if Scanner.rectCache.top >= Scanner.limiteSuperiorY and Scanner.rectCache.bottom <= Scanner.limiteInferiorY then
                        if not Scanner.esBotonDinamico(tLower, tNorm) then
                            local contenedor = nodo
                            local padre = nodo.getParent()
                            if padre and not padre.isScrollable() then contenedor = padre end
                            
                            local comentarioCompleto = Scanner.extraerContenedor(contenedor)
                            
                            if comentarioCompleto ~= "" and not Scanner.cajasProcesadas[comentarioCompleto] then
                                Scanner.cajasProcesadas[comentarioCompleto] = true
                                local cLower = comentarioCompleto:lower()
                                local cNorm = cLower:gsub("[%s%p]", "")
                                
                                if not Scanner.esBotonDinamico(cLower, cNorm) and not Scanner.esDuplicado(cNorm) then
                                    local esSistema = cLower:find("te damos la bienvenida") or cLower:find("normas de la comunidad") or cLower:find("para recargar")
                                    
                                    local cFuerte = normalizarTextoFuerte(comentarioCompleto)
                                    local esProhibida = false
                                    for p, _ in pairs(Scanner.palabrasProhibidas) do
                                        if cFuerte:find(p, 1, true) then esProhibida = true break end
                                    end
                                    
                                    if not esSistema then
                                        if esProhibida then
                                            Scanner.registrarHistorial(cNorm)
                                            if AppState.config.avisarFiltro then
                                                local leerAviso = false
                                                if AppState.config.fraseFiltro and AppState.config.fraseFiltro ~= "" then leerAviso = true end
                                                table.insert(Scanner.lecturasPendientes, {texto = AppState.config.fraseFiltro, leer = leerAviso, snd = AudioEngine.sonidos.filtro, y = Scanner.rectCache.top})
                                            end
                                        else
                                            Scanner.registrarHistorial(cNorm)
                                            local cLimpio = Scanner.reducirSpam(comentarioCompleto)
                                            local esMsg = cLower:find(":") or cLower:find(" dice: ")
                                            
                                            local idSonido = nil
                                            local leer = true
                                            
                                            if cLower:find("se unió") or cLower:find("joined") then idSonido = AudioEngine.sonidos.uniones; leer = AppState.config.leerUniones
                                            elseif cLower:find("me gusta") then idSonido = AudioEngine.sonidos.likes; leer = AppState.config.leerLikes
                                            elseif cLower:find("compartió") then idSonido = AudioEngine.sonidos.compartidas; leer = AppState.config.leerCompartidas
                                            elseif (cLower:find("siguió") or cLower:find("seguir")) and not esMsg then idSonido = AudioEngine.sonidos.seguidores; leer = AppState.config.leerSeguidores
                                            elseif cLower:find("envió") and not esMsg then idSonido = AudioEngine.sonidos.regalos; leer = AppState.config.leerRegalos
                                            end
                                            
                                            table.insert(Scanner.lecturasPendientes, {texto = cLimpio, leer = leer, snd = idSonido, y = Scanner.rectCache.top})
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            for i = 0, nodo.getChildCount() - 1 do explorar(nodo.getChild(i)) end
        end
        explorar(root)
    end)

    if not esEntornoValido then
        if not AppState.pausado then
            AppState.pausado = true
            local modoPausa = AppState.recienIniciado and 1 or 0
            AudioEngine.hablar("Chat oculto. Pausando.", modoPausa)
        end
    else
        if AppState.pausado then
            AppState.pausado = false
            AudioEngine.hablar("Reanudando lector.", 0)
        end
        
        if not panelAbierto then
            table.sort(Scanner.lecturasPendientes, function(a, b) return a.y < b.y end)
            for _, item in ipairs(Scanner.lecturasPendientes) do
                if item.snd and AudioEngine.pool and AudioEngine.listos[item.snd] then 
                    pcall(function() AudioEngine.pool.play(item.snd, 1, 1, 0, 0, 1) end) 
                end
                if item.leer then AudioEngine.hablar(item.texto, 1) end
            end
        end
    end

    AppState.recienIniciado = false
    if AppState.activo then AppState.handler.postDelayed(AppState.runnable, 400) end
end

local function iniciarLectorSilencioso()
    if AppState.runnable then
        pcall(function() AppState.handler.removeCallbacks(AppState.runnable) end)
        AppState.runnable = nil
    end

    AppState.config = {
        velocidad = pref.getFloat("velocidad", 2.0),
        leerConDice = pref.getBoolean("leerConDice", false),
        leerUniones = pref.getBoolean("leerUniones", false),
        leerLikes = pref.getBoolean("leerLikes", false),
        leerCompartidas = pref.getBoolean("leerCompartidas", true),
        leerSeguidores = pref.getBoolean("leerSeguidores", true),
        leerRegalos = pref.getBoolean("leerRegalos", true),
        filtro = pref.getString("filtroPalabras", defaultFiltro),
        avisarFiltro = pref.getBoolean("avisarFiltro", true),
        fraseFiltro = pref.getString("fraseFiltro", "Comentario omitido"),
        sndFiltro = pref.getString("sndFiltro", ""),
        motor = pref.getString("paqueteMotor", ""),
        voz = pref.getString("nombreVoz", ""),
        sndUniones = pref.getString("sndUniones", ""),
        sndLikes = pref.getString("sndLikes", ""),
        sndCompartidas = pref.getString("sndCompartidas", ""),
        sndSeguidores = pref.getString("sndSeguidores", ""),
        sndRegalos = pref.getString("sndRegalos", ""),
        canalAccesibilidad = pref.getBoolean("canalAccesibilidad", false)
    }

    AudioEngine.cargarSonidos(AppState.config)
    Scanner.prepararFiltros()
    Scanner.pantallaConfigurada = false
    AppState.historialHash = {}
    AppState.historialArray = {}
    AppState.indiceHistorial = 1
    AppState.activo = true
    AppState.pausado = false
    AppState.recienIniciado = true

    local listener = TextToSpeech.OnInitListener({
        onInit = function(status)
            if status == TextToSpeech.SUCCESS then
                pcall(function()
                    local attrBuilder = AudioAttributes.Builder().setContentType(1)
                    if AppState.config.canalAccesibilidad then
                        attrBuilder.setUsage(11)
                    else
                        attrBuilder.setUsage(1)
                    end
                    AppState.tts.setAudioAttributes(attrBuilder.build())
                end)

                pcall(function()
                    if AppState.config.voz ~= "" then
                        local voces = AppState.tts.getVoices()
                        if voces then
                            local it = voces.iterator()
                            while it.hasNext() do
                                local v = it.next()
                                if v.getName() == AppState.config.voz then AppState.tts.setVoice(v); break end
                            end
                        end
                    end
                    AppState.tts.setSpeechRate(AppState.config.velocidad)
                    AppState.tts.speak("Lector de TikTok activado. Creado por LS Accesible.", 1, nil, "INIT_ID")
                end)
                
                AppState.runnable = Runnable({ run = Scanner.ejecutarCiclo })
                AppState.handler.postDelayed(AppState.runnable, 3000)
            else
                AppState.activo = false
                service.speak("Error en el motor TTS.")
            end
        end
    })

    if AppState.config.motor ~= "" then AppState.tts = TextToSpeech(service, listener, AppState.config.motor) else AppState.tts = TextToSpeech(service, listener) end
end

local function detenerLectorSilencioso()
    AppState.activo = false
    AppState.pausado = false
    AudioEngine.detenerReproductorActual()
    if AudioEngine.pool then pcall(function() AudioEngine.pool.release(); AudioEngine.pool = nil end) end
    
    if AppState.tts then
        local ttsViejo = AppState.tts
        AppState.tts = nil
        pcall(function() 
            ttsViejo.speak("Lector de TikTok desactivado.", 0, nil, "OFF_ID") 
        end)
        AppState.handler.postDelayed(Runnable({
            run = function() pcall(function() if ttsViejo then ttsViejo.shutdown() end end) end
        }), 2000)
    end
    if AppState.runnable then AppState.handler.removeCallbacks(AppState.runnable) end
end

-- ==========================================
-- EXPLORADOR Y MENÚS
-- ==========================================
local function abrirExplorador(clavePref, titulo, rutaActual)
    local dir = File(rutaActual)
    if not dir.exists() or not dir.canRead() then return service.speak("No se puede acceder a esta carpeta.") end

    local archivos = dir.listFiles()
    local carpetas, audios = {}, {}

    if archivos then
        for i = 0, #archivos - 1 do
            local f = archivos[i]
            local nombre = f.getName()
            local lowerName = string.lower(nombre)
            
            if not string.match(nombre, "^%.") and lowerName ~= "android" then
                if f.isDirectory() then 
                    table.insert(carpetas, f)
                else
                    local ext = nombre:match("^.+(%..+)$")
                    if ext and (ext:lower() == ".mp3" or ext:lower() == ".wav" or ext:lower() == ".ogg" or ext:lower() == ".m4a") then
                        table.insert(audios, f)
                    end
                end
            end
        end
    end

    table.sort(carpetas, function(a, b) return a.getName():lower() < b.getName():lower() end)
    table.sort(audios, function(a, b) return a.getName():lower() < b.getName():lower() end)

    local sonidoGuardadoActual = pref.getString(clavePref, "")
    local rutaRaiz = Environment.getExternalStorageDirectory().getAbsolutePath()
    local alert = nil
    local seleccionTemporalAudio = nil

    local rootLayout = LinearLayout(service)
    rootLayout.setOrientation(1)
    rootLayout.setBackgroundColor(Color.parseColor(colorFondoApp))

    local scrollLista = ScrollView(service)
    local layoutLista = LinearLayout(service)
    layoutLista.setOrientation(1)
    layoutLista.setPadding(20, 20, 20, 20)
    scrollLista.addView(layoutLista)
    
    local paramsScroll = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1.0)
    scrollLista.setLayoutParams(paramsScroll)
    rootLayout.addView(scrollLista)

    local function crearItem(texto, onClickItem, esSel)
        local txt = TextView(service)
        txt.setText(texto)
        txt.setTextSize(18)
        if esSel then
            txt.setTextColor(Color.parseColor(colorFondoRojo))
        else
            txt.setTextColor(Color.parseColor(colorTextoBlanco))
        end
        txt.setPadding(30, 45, 30, 45)
        txt.setClickable(true)
        txt.onClick = onClickItem
        return txt
    end

    layoutLista.addView(crearItem("[Silenciar este sonido]", function(v)
        AudioEngine.detenerReproductorActual()
        seleccionTemporalAudio = "SILENCIO"
        service.speak("Silenciado")
    end, false))

    if dir.getAbsolutePath() ~= rutaRaiz then
        layoutLista.addView(crearItem("[Volver a la carpeta anterior]", function(v)
            AudioEngine.detenerReproductorActual()
            if alert then alert.dismiss() end
            abrirExplorador(clavePref, titulo, dir.getParent())
        end, false))
        
        if dir.getParent() ~= rutaRaiz then
            layoutLista.addView(crearItem("[Ir a la memoria interna principal]", function(v)
                AudioEngine.detenerReproductorActual()
                if alert then alert.dismiss() end
                abrirExplorador(clavePref, titulo, rutaRaiz)
            end, false))
        end
    end

    for _, c in ipairs(carpetas) do
        layoutLista.addView(crearItem(c.getName(), function(v)
            AudioEngine.detenerReproductorActual()
            if alert then alert.dismiss() end
            abrirExplorador(clavePref, titulo, c.getAbsolutePath())
        end, false))
    end

    for _, a in ipairs(audios) do
        local rutaAbs = a.getAbsolutePath()
        local esSel = (rutaAbs == sonidoGuardadoActual)
        local etiqueta = a.getName()
        if esSel then etiqueta = etiqueta .. " (Seleccionado)" end

        layoutLista.addView(crearItem(etiqueta, function(v)
            seleccionTemporalAudio = rutaAbs
            service.speak("Seleccionado")
            AudioEngine.alternarReproduccionMuestra(rutaAbs)
        end, esSel))
    end

    local bottomLayout = LinearLayout(service)
    bottomLayout.setOrientation(0)
    bottomLayout.setPadding(20, 20, 20, 20)
    bottomLayout.setBackgroundColor(Color.parseColor("#111111"))

    local btnCancelar = crearBotonPersonalizado("Cancelar", function()
        AudioEngine.detenerReproductorActual()
        if alert then alert.dismiss() end
    end, false)
    local pCancel = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0)
    pCancel.setMargins(0, 0, 10, 0)
    btnCancelar.setLayoutParams(pCancel)
    bottomLayout.addView(btnCancelar)

    local btnGuardar = crearBotonPersonalizado("Guardar Sonido", function()
        AudioEngine.detenerReproductorActual()
        if seleccionTemporalAudio then
            if seleccionTemporalAudio == "SILENCIO" then
                pref.edit().putString(clavePref, "").commit()
                service.speak("Sonido desactivado guardado.")
            else
                pref.edit().putString(clavePref, seleccionTemporalAudio).commit()
                service.speak("Sonido guardado.")
            end
        end
        if alert then alert.dismiss() end
    end, true)
    local pGuardar = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0)
    pGuardar.setMargins(10, 0, 0, 0)
    btnGuardar.setLayoutParams(pGuardar)
    bottomLayout.addView(btnGuardar)

    rootLayout.addView(bottomLayout)

    local builder = AlertDialog.Builder(service)
    builder.setTitle("Audio para: " .. titulo .. "\nCarpeta actual: " .. dir.getName())
    builder.setView(rootLayout)
    alert = builder.create()
    alert.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    alert.show()
end

local function abrirMenuVoz()
    local alert
    local layoutVoz = LinearLayout(service)
    layoutVoz.setOrientation(1)
    aplicarEstiloLayout(layoutVoz)

    local scrollVoz = ScrollView(service)
    scrollVoz.setBackgroundColor(Color.parseColor(colorFondoApp))
    scrollVoz.addView(layoutVoz)

    local menuTTS = nil
    
    local function recrearTTS()
        if menuTTS then
            pcall(function() menuTTS.shutdown() end)
            menuTTS = nil
        end
        local motorGuardadoActual = pref.getString("paqueteMotor", "")
        local listenerTTS = TextToSpeech.OnInitListener({
            onInit = function(status)
                if status == TextToSpeech.SUCCESS then
                    pcall(function()
                        local attrBuilder = AudioAttributes.Builder().setContentType(1)
                        if pref.getBoolean("canalAccesibilidad", false) then
                            attrBuilder.setUsage(11)
                        else
                            attrBuilder.setUsage(1)
                        end
                        menuTTS.setAudioAttributes(attrBuilder.build())
                    end)

                    local vozGuardada = pref.getString("nombreVoz", "")
                    if vozGuardada ~= "" then
                        local voces = menuTTS.getVoices()
                        if voces then
                            local it = voces.iterator()
                            while it.hasNext() do
                                local v = it.next()
                                if v.getName() == vozGuardada then
                                    menuTTS.setVoice(v)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        })

        if motorGuardadoActual ~= "" then
            menuTTS = TextToSpeech(service, listenerTTS, motorGuardadoActual)
        else
            menuTTS = TextToSpeech(service, listenerTTS)
        end
    end

    recrearTTS()

    local btnSeleccionarMotor = crearBotonPersonalizado("Seleccionar motor de voz", function(v)
        if not menuTTS then recrearTTS() end
        service.speak("Buscando motores instalados...")
        local motores = menuTTS.getEngines()
        
        local motorGuardadoLista = pref.getString("paqueteMotor", "")
        local nombresMotores = {"[Motor por defecto del sistema]"}
        local paquetesMotores = {"DEFAULT"}
        local checkedIndex = 0
        
        if motores then
            local it = motores.iterator()
            local i = 1
            while it.hasNext() do
                local info = it.next()
                local pkgName = tostring(info.name)
                local labelStr = tostring(info.label)
                table.insert(nombresMotores, labelStr)
                table.insert(paquetesMotores, pkgName)
                if pkgName == motorGuardadoLista then checkedIndex = i end
                i = i + 1
            end
        end

        local seleccionTemporalMotor = checkedIndex + 1
        local builder = AlertDialog.Builder(service)
        builder.setTitle("Selecciona el Motor")
        builder.setSingleChoiceItems(nombresMotores, checkedIndex, function(dialog, which)
            seleccionTemporalMotor = which + 1
        end)
        builder.setPositiveButton("Guardar Motor", DialogInterface.OnClickListener({
            onClick = function(dialog, which)
                if seleccionTemporalMotor then
                    local idx = seleccionTemporalMotor
                    if idx == 1 then
                        pref.edit().putString("paqueteMotor", "").putString("nombreVoz", "").commit()
                    else
                        pref.edit().putString("paqueteMotor", paquetesMotores[idx]).putString("nombreVoz", "").commit()
                    end
                    service.speak("Motor guardado.")
                    recrearTTS()
                end
            end
        }))
        builder.setNegativeButton("Cancelar", nil)
        local alertMotor = builder.create()
        alertMotor.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        alertMotor.show()
    end, false)
    layoutVoz.addView(btnSeleccionarMotor)

    local btnSeleccionarVoz = crearBotonPersonalizado("Elegir voz específica", function(v)
        if not menuTTS then recrearTTS() end
        service.speak("Cargando voces del motor...")
        local voces = menuTTS.getVoices()
        if voces ~= nil then
            local vozGuardadaLista = pref.getString("nombreVoz", "")
            local nombresLista = {"[Voz por defecto]"}
            local objetosVoz = {"DEFAULT"}
            local checkedIndex = 0
            
            local it = voces.iterator()
            local i = 1
            while it.hasNext() do
                local voz = it.next()
                local idioma = ""
                local locale = voz.getLocale()
                if locale ~= nil then idioma = tostring(locale.getDisplayLanguage()) end
                
                local labelVoz = voz.getName() .. " (" .. idioma .. ")"
                table.insert(nombresLista, labelVoz)
                table.insert(objetosVoz, voz)
                if voz.getName() == vozGuardadaLista then checkedIndex = i end
                i = i + 1
            end
            
            local seleccionTemporalVoz = checkedIndex + 1
            local builderVoces = AlertDialog.Builder(service)
            builderVoces.setTitle("Selecciona una voz")
            builderVoces.setSingleChoiceItems(nombresLista, checkedIndex, function(dialog, which)
                seleccionTemporalVoz = which + 1
                if seleccionTemporalVoz == 1 then
                    pcall(function()
                        menuTTS.setLanguage(menuTTS.getDefaultLanguage())
                        menuTTS.speak("Voz seleccionada.", 0, nil)
                    end)
                else
                    pcall(function()
                        local vozElegida = objetosVoz[seleccionTemporalVoz]
                        menuTTS.setVoice(vozElegida)
                        menuTTS.speak("Voz seleccionada.", 0, nil)
                    end)
                end
            end)
            builderVoces.setPositiveButton("Guardar Voz", DialogInterface.OnClickListener({
                onClick = function(dialog, which)
                    if seleccionTemporalVoz then
                        local idx = seleccionTemporalVoz
                        if idx == 1 then pref.edit().putString("nombreVoz", "").commit()
                        else pref.edit().putString("nombreVoz", objetosVoz[idx].getName()).commit() end
                        service.speak("Voz guardada.")
                    end
                end
            }))
            builderVoces.setNegativeButton("Cancelar", nil)
            local alertVoces = builderVoces.create()
            alertVoces.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
            alertVoces.show()
        else
            service.speak("No se pudieron obtener las voces de este motor.")
        end
    end, false)
    layoutVoz.addView(btnSeleccionarVoz)

    local lblVelocidad = TextView(service)
    lblVelocidad.setText("Velocidad del habla:")
    aplicarEstiloTexto(lblVelocidad)
    local paramsLbl = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    paramsLbl.setMargins(0, 30, 0, 10)
    lblVelocidad.setLayoutParams(paramsLbl)
    layoutVoz.addView(lblVelocidad)

    local velocidadGuardada = pref.getFloat("velocidad", 2.0)
    local barraSpeed = SeekBar(service)
    barraSpeed.setContentDescription("Control de velocidad del habla") 
    barraSpeed.setMax(40)
    barraSpeed.setProgress(math.floor(velocidadGuardada * 10))
    
    local paramsBarra = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    paramsBarra.setMargins(0, 0, 0, 30)
    barraSpeed.setLayoutParams(paramsBarra)

    local chkAccesibilidad = CheckBox(service)
    chkAccesibilidad.setText("Usar volumen de Accesibilidad (Separar de multimedia)")
    chkAccesibilidad.setChecked(pref.getBoolean("canalAccesibilidad", false))
    aplicarEstiloTexto(chkAccesibilidad)

    local chkDice = CheckBox(service); chkDice.setText("Agregar 'dice' entre nombre y mensaje"); chkDice.setChecked(pref.getBoolean("leerConDice", false)); aplicarEstiloTexto(chkDice);
    local chkUniones = CheckBox(service); chkUniones.setText("Leer uniones al Live"); chkUniones.setChecked(pref.getBoolean("leerUniones", false)); aplicarEstiloTexto(chkUniones);
    local chkLikes = CheckBox(service); chkLikes.setText("Leer los 'Me gusta'"); chkLikes.setChecked(pref.getBoolean("leerLikes", false)); aplicarEstiloTexto(chkLikes);
    local chkCompartidas = CheckBox(service); chkCompartidas.setText("Leer cuando comparten"); chkCompartidas.setChecked(pref.getBoolean("leerCompartidas", true)); aplicarEstiloTexto(chkCompartidas);
    local chkSeguidores = CheckBox(service); chkSeguidores.setText("Leer nuevos seguidores"); chkSeguidores.setChecked(pref.getBoolean("leerSeguidores", true)); aplicarEstiloTexto(chkSeguidores);
    local chkRegalos = CheckBox(service); chkRegalos.setText("Leer regalos"); chkRegalos.setChecked(pref.getBoolean("leerRegalos", true)); aplicarEstiloTexto(chkRegalos);

    local function autoGuardar()
        local nuevaVelocidad = barraSpeed.getProgress() / 10.0
        if nuevaVelocidad < 0.1 then nuevaVelocidad = 0.1 end
        pref.edit()
            .putFloat("velocidad", nuevaVelocidad)
            .putBoolean("canalAccesibilidad", chkAccesibilidad.isChecked())
            .putBoolean("leerConDice", chkDice.isChecked())
            .putBoolean("leerUniones", chkUniones.isChecked())
            .putBoolean("leerLikes", chkLikes.isChecked())
            .putBoolean("leerCompartidas", chkCompartidas.isChecked())
            .putBoolean("leerSeguidores", chkSeguidores.isChecked())
            .putBoolean("leerRegalos", chkRegalos.isChecked())
            .commit()
    end

    chkAccesibilidad.onClick = function(v)
        autoGuardar()
        if menuTTS then
            pcall(function()
                local attrBuilder = AudioAttributes.Builder().setContentType(1)
                if chkAccesibilidad.isChecked() then attrBuilder.setUsage(11) else attrBuilder.setUsage(1) end
                menuTTS.setAudioAttributes(attrBuilder.build())
            end)
        end
    end
    chkDice.onClick = function(v) autoGuardar() end
    chkUniones.onClick = function(v) autoGuardar() end
    chkLikes.onClick = function(v) autoGuardar() end
    chkCompartidas.onClick = function(v) autoGuardar() end
    chkSeguidores.onClick = function(v) autoGuardar() end
    chkRegalos.onClick = function(v) autoGuardar() end

    local debounceRunnable = nil
    barraSpeed.setOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener({
        onProgressChanged = function(seekBar, progress, fromUser)
            local val = progress / 10.0
            if val < 0.1 then val = 0.1 end
            pref.edit().putFloat("velocidad", val).commit()
            if debounceRunnable then AppState.handler.removeCallbacks(debounceRunnable) end
            debounceRunnable = Runnable({
                run = function()
                    if menuTTS then
                        pcall(function()
                            local porcentaje = math.floor((progress / 40) * 100)
                            menuTTS.setSpeechRate(val)
                            menuTTS.speak(porcentaje .. " por ciento", 0, nil, "P_ID")
                        end)
                    end
                end
            })
            AppState.handler.postDelayed(debounceRunnable, 400)
        end,
        onStartTrackingTouch = function(seekBar) end,
        onStopTrackingTouch = function(seekBar) autoGuardar() end
    }))
    layoutVoz.addView(barraSpeed)
    layoutVoz.addView(chkAccesibilidad)
    layoutVoz.addView(chkDice)
    layoutVoz.addView(chkUniones)
    layoutVoz.addView(chkLikes)
    layoutVoz.addView(chkCompartidas)
    layoutVoz.addView(chkSeguidores)
    layoutVoz.addView(chkRegalos)

    local btnCerrarVoz = crearBotonPersonalizado("Aceptar / Cerrar", function()
        autoGuardar()
        service.speak("Cambios guardados.")
        if alert then alert.dismiss() end
    end, true)
    layoutVoz.addView(btnCerrarVoz)

    local builder = AlertDialog.Builder(service)
    builder.setView(scrollVoz)
    alert = builder.create()
    alert.setOnDismissListener(DialogInterface.OnDismissListener({
        onDismiss = function(dialog)
            autoGuardar()
            if menuTTS then pcall(function() menuTTS.shutdown() end) end
        end
    }))
    alert.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    alert.show()
end

local function abrirMenuSonidos()
    local alert
    local layoutSonido = LinearLayout(service)
    layoutSonido.setOrientation(1)
    aplicarEstiloLayout(layoutSonido)
    
    local rutaCarpetaEspecial = Environment.getExternalStorageDirectory().getAbsolutePath() .. "/LSTikTok_Sonidos"
    local rutaInicio = rutaCarpetaEspecial
    if not File(rutaCarpetaEspecial).exists() then rutaInicio = Environment.getExternalStorageDirectory().getAbsolutePath() end

    local btnSndUniones = crearBotonPersonalizado("Sonido: Uniones al Live", function() abrirExplorador("sndUniones", "Uniones", rutaInicio) end, false); layoutSonido.addView(btnSndUniones)
    local btnSndLikes = crearBotonPersonalizado("Sonido: Me Gusta", function() abrirExplorador("sndLikes", "Me Gusta", rutaInicio) end, false); layoutSonido.addView(btnSndLikes)
    local btnSndCompartidas = crearBotonPersonalizado("Sonido: Compartidas", function() abrirExplorador("sndCompartidas", "Compartidas", rutaInicio) end, false); layoutSonido.addView(btnSndCompartidas)
    local btnSndSeguidores = crearBotonPersonalizado("Sonido: Nuevos Seguidores", function() abrirExplorador("sndSeguidores", "Nuevos Seguidores", rutaInicio) end, false); layoutSonido.addView(btnSndSeguidores)
    local btnSndRegalos = crearBotonPersonalizado("Sonido: Regalos", function() abrirExplorador("sndRegalos", "Regalos", rutaInicio) end, false); layoutSonido.addView(btnSndRegalos)

    local btnDescargarPaquete = crearBotonPersonalizado("Descargar Paquete de Sonidos", descargarPaqueteSonidos, true)
    layoutSonido.addView(btnDescargarPaquete)

    local btnLimpiar = crearBotonPersonalizado("Eliminar todos los sonidos descargados", function()
        local dir = File(Environment.getExternalStorageDirectory().getAbsolutePath() .. "/LSTikTok_Sonidos")
        if dir.exists() then
            eliminarCarpetaRecursivamente(dir)
            service.speak("Todos los sonidos descargados han sido eliminados por completo del teléfono.")
        else
            service.speak("La carpeta de sonidos ya estaba vacía o no existe.")
        end
    end, false)
    layoutSonido.addView(btnLimpiar)

    local btnCerrar = crearBotonPersonalizado("Cerrar Sonidos", function() if alert then alert.dismiss() end end, false)
    layoutSonido.addView(btnCerrar)

    local scrollSonido = ScrollView(service)
    scrollSonido.addView(layoutSonido)
    scrollSonido.setBackgroundColor(Color.parseColor(colorFondoApp))
    local builder = AlertDialog.Builder(service)
    builder.setView(scrollSonido)
    alert = builder.create()
    alert.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    alert.show()
end

local function abrirMenuAlertasFiltro()
    local alertAlertas
    local layoutAlertas = LinearLayout(service)
    layoutAlertas.setOrientation(1)
    aplicarEstiloLayout(layoutAlertas)

    local lblTituloAlertas = TextView(service)
    lblTituloAlertas.setText("Configuración de Alertas")
    lblTituloAlertas.setTextColor(Color.parseColor(colorTextoBlanco))
    lblTituloAlertas.setTextSize(18)
    lblTituloAlertas.setGravity(Gravity.CENTER)
    lblTituloAlertas.setPadding(0, 0, 0, 30)
    layoutAlertas.addView(lblTituloAlertas)

    local chkAvisar = CheckBox(service)
    chkAvisar.setText("Notificar comentarios bloqueados")
    chkAvisar.setChecked(pref.getBoolean("avisarFiltro", true))
    aplicarEstiloTexto(chkAvisar)
    layoutAlertas.addView(chkAvisar)

    local txtFraseAlerta = EditText(service)
    txtFraseAlerta.setHint("Frase de aviso")
    txtFraseAlerta.setText(pref.getString("fraseFiltro", "Comentario omitido"))
    txtFraseAlerta.setTextColor(Color.parseColor(colorTextoBlanco))
    txtFraseAlerta.setHintTextColor(Color.parseColor("#AAAAAA"))
    layoutAlertas.addView(txtFraseAlerta)
    
    local rutaCarpetaEspecial = Environment.getExternalStorageDirectory().getAbsolutePath() .. "/LSTikTok_Sonidos"
    local rutaInicio = rutaCarpetaEspecial
    if not File(rutaCarpetaEspecial).exists() then rutaInicio = Environment.getExternalStorageDirectory().getAbsolutePath() end
    
    local btnSndFiltro = crearBotonPersonalizado("Elegir Sonido de Bloqueo", function() abrirExplorador("sndFiltro", "Alerta de Bloqueo", rutaInicio) end, false)
    layoutAlertas.addView(btnSndFiltro)
    
    local btnGuardarAlertas = crearBotonPersonalizado("Guardar y Cerrar Alertas", function()
        pref.edit().putBoolean("avisarFiltro", chkAvisar.isChecked())
                   .putString("fraseFiltro", txtFraseAlerta.getText().toString())
                   .commit()
        if AppState.config then
            AppState.config.avisarFiltro = chkAvisar.isChecked()
            AppState.config.fraseFiltro = txtFraseAlerta.getText().toString()
        end
        service.speak("Configuración guardada.")
        if alertAlertas then alertAlertas.dismiss() end
    end, true)
    layoutAlertas.addView(btnGuardarAlertas)

    local scrollAlertas = ScrollView(service)
    scrollAlertas.addView(layoutAlertas)
    scrollAlertas.setBackgroundColor(Color.parseColor(colorFondoApp))
    
    local builder = AlertDialog.Builder(service)
    builder.setView(scrollAlertas)
    alertAlertas = builder.create()
    alertAlertas.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    alertAlertas.show()
end

local function abrirMenuFiltros()
    local alert
    local layoutFiltro = LinearLayout(service)
    layoutFiltro.setOrientation(1)
    aplicarEstiloLayout(layoutFiltro)

    local txtNuevaFrase = EditText(service)
    txtNuevaFrase.setHint("Escribe la palabra prohibida")
    txtNuevaFrase.setTextColor(Color.parseColor(colorTextoBlanco))
    txtNuevaFrase.setHintTextColor(Color.parseColor("#AAAAAA"))
    layoutFiltro.addView(txtNuevaFrase)

    local btnAdd = crearBotonPersonalizado("Añadir palabra", nil, true)
    layoutFiltro.addView(btnAdd)
    
    local btnAbrirAlertas = crearBotonPersonalizado("Configurar Alertas de Bloqueo", abrirMenuAlertasFiltro, false)
    layoutFiltro.addView(btnAbrirAlertas)

    local lblLista = TextView(service)
    lblLista.setText("Lista de Palabras Prohibidas")
    lblLista.setTextColor(Color.parseColor("#AAAAAA"))
    lblLista.setGravity(Gravity.CENTER)
    lblLista.setPadding(0, 30, 0, 10)
    layoutFiltro.addView(lblLista)

    local listaLayout = LinearLayout(service)
    listaLayout.setOrientation(1)
    listaLayout.setBackgroundColor(Color.parseColor(colorFondoApp))
    local scrollFiltro = ScrollView(service)
    scrollFiltro.addView(listaLayout)

    local layoutContenedor = LinearLayout(service)
    layoutContenedor.setOrientation(1)
    layoutContenedor.addView(layoutFiltro)
    layoutContenedor.addView(scrollFiltro)
    layoutContenedor.setBackgroundColor(Color.parseColor(colorFondoApp))

    local function refrescarLista()
        listaLayout.removeAllViews()
        local str = pref.getString("filtroPalabras", defaultFiltro)
        local palabras = {}
        if str ~= "" then for w in string.gmatch(str, "([^|]+)") do table.insert(palabras, w) end end
        for i, p in ipairs(palabras) do
            local btnDel = crearBotonPersonalizado("Eliminar: " .. p, function(v)
                table.remove(palabras, i)
                pref.edit().putString("filtroPalabras", table.concat(palabras, "|")).commit()
                refrescarLista()
                service.speak("Palabra eliminada")
            end, true)
            listaLayout.addView(btnDel)
        end
        local btnCerrar = crearBotonPersonalizado("Cerrar Filtros", function() if alert then alert.dismiss() end end, false)
        listaLayout.addView(btnCerrar)
    end

    btnAdd.onClick = function(v)
        local txt = txtNuevaFrase.getText().toString()
        if txt ~= "" then
            local str = pref.getString("filtroPalabras", defaultFiltro)
            local palabras = {}
            if str ~= "" then for w in string.gmatch(str, "([^|]+)") do table.insert(palabras, w) end end
            table.insert(palabras, txt)
            pref.edit().putString("filtroPalabras", table.concat(palabras, "|")).commit()
            txtNuevaFrase.setText("")
            refrescarLista()
            service.speak("Palabra añadida")
        end
    end

    refrescarLista()
    local builder = AlertDialog.Builder(service)
    builder.setView(layoutContenedor)
    alert = builder.create()
    alert.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    alert.show()
end

local function abrirMenuPrincipal()
    comprobarActualizacion(false)

    local alert
    local layoutRoot = LinearLayout(service)
    layoutRoot.setOrientation(1)
    aplicarEstiloLayout(layoutRoot)

    local lblTitulo = TextView(service)
    lblTitulo.setText("Configuración: Lector TikTok Pro")
    lblTitulo.setTextColor(Color.parseColor(colorTextoBlanco))
    lblTitulo.setTextSize(20)
    lblTitulo.setGravity(Gravity.CENTER)
    lblTitulo.setPadding(0, 0, 0, 40)
    layoutRoot.addView(lblTitulo)

    local btnMenuVoz = crearBotonPersonalizado("Configuración de voz", abrirMenuVoz, false); layoutRoot.addView(btnMenuVoz)
    local btnMenuSonidos = crearBotonPersonalizado("Configuración de sonidos", abrirMenuSonidos, false); layoutRoot.addView(btnMenuSonidos)
    local btnMenuFiltros = crearBotonPersonalizado("Filtro de palabras", abrirMenuFiltros, false); layoutRoot.addView(btnMenuFiltros)

    local btnBuscarUpdate = crearBotonPersonalizado("Buscar actualizaciones", function()
        service.speak("Comprobando actualizaciones...")
        comprobarActualizacion(true)
    end, false)
    layoutRoot.addView(btnBuscarUpdate)

    local btnTelegram = crearBotonPersonalizado("Unirse al canal de Telegram", function()
        if alert then alert.dismiss() end
        pcall(function()
            local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/Accesiblels"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
        end)
        service.speak("Abriendo Telegram")
    end, false)
    layoutRoot.addView(btnTelegram)

    local lblMarca = TextView(service)
    lblMarca.setText("Creado por LS Accesible")
    lblMarca.setTextColor(Color.parseColor(colorTextoBlanco))
    lblMarca.setGravity(Gravity.CENTER)
    lblMarca.setPadding(0, 40, 0, 40)
    layoutRoot.addView(lblMarca)

    local layoutBotonesBottom = LinearLayout(service)
    layoutBotonesBottom.setOrientation(0)

    local btnCerrar = crearBotonPersonalizado("Cerrar Menú", function() service.speak("Menú cerrado."); if alert then alert.dismiss() end end, true)
    local paramCerrar = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0)
    paramCerrar.setMargins(0, 15, 15, 15)
    btnCerrar.setLayoutParams(paramCerrar)
    layoutBotonesBottom.addView(btnCerrar)

    local btnIniciar = crearBotonPersonalizado("Iniciar Voz", function() if alert then alert.dismiss() end; iniciarLectorSilencioso() end, true)
    local paramIniciar = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0)
    paramIniciar.setMargins(15, 15, 0, 15)
    btnIniciar.setLayoutParams(paramIniciar)
    layoutBotonesBottom.addView(btnIniciar)

    layoutRoot.addView(layoutBotonesBottom)
    local builder = AlertDialog.Builder(service)
    builder.setView(layoutRoot)
    alert = builder.create()
    alert.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
    alert.show()
end

local exitoRaiz, nodoRaiz = pcall(function() return service.getRootInActiveWindow() end)
local paqueteActual = ""
if exitoRaiz and nodoRaiz then pcall(function() paqueteActual = tostring(nodoRaiz.getPackageName() or "") end) end

if AppState.activo then detenerLectorSilencioso(); return true end
if paqueteActual == "com.zhiliaoapp.musically" or paqueteActual == "com.ss.android.ugc.trill" then iniciarLectorSilencioso() else abrirMenuPrincipal() end
return true
