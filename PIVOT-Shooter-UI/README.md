# PIVOT · UI de shooter competitivo en Roblox Studio

Proyecto personal de portafolio: un sistema completo de interfaz para un shooter competitivo,
hecho con ScreenGuis nativas y Luau, con datos simulados y un recorrido jugable en Play Mode.
No es un shooter real. El grupo, el matchmaking, la tienda, la red y las partidas se simulan
en el cliente, sin servidores, sin DataStore y sin compras reales (no usa MarketplaceService).

## Contenido

| Carpeta | Qué hay |
|---|---|
| `place/PIVOT_ShooterUI.rbxl` | El place editable: scripts, decorado 3D del lobby y de la partida, modelos sustitutos e iluminación |
| `src/` | Todos los scripts, con la misma jerarquía que en Studio (`*.module.luau`, `*.client.luau`) |
| `art/` | Atlas de UI propio (76 iconos, emblemas, piezas 9-slice y efectos de HUD), su generador y su mapa |
| `tools/` | Extractor y parcheador de `.rbxl`, y el script de recuperación de la sesión del 13/11 |

## Abrir y probar

1. Abre `place/PIVOT_ShooterUI.rbxl` en Roblox Studio.
2. Pega una vez `tools/post_recovery_fixups.luau` en la barra de comandos (ajustes del decorado posteriores a la copia automática).
3. Para tener el atlas, copia `art/pivot_atlas.png` a `content/textures/pivot/` de tu instalación de Studio, o súbelo como imagen y pon su id en `Icons.uploaded` (`src/ReplicatedStorage/PivotUI/Icons.module.luau`).
4. Pulsa Play. El recorrido entero se hace con los botones normales.

**Teclado**
- Lobby: Q / E cambian de sección, las flechas e Intro navegan con foco visible y Retroceso cierra los diálogos (Escape está reservado por Roblox).
- Partida: clic o Espacio dispara, clic derecho apunta, R recarga, 1 / 2 o la rueda cambian de arma, G usa el apoyo, Tab (mantener) abre las puntuaciones y P pausa.

**Panel de demostración:** pestaña «DEMO» del borde izquierdo o la tecla `. Es una herramienta del presentador, no forma parte del juego. Simula desconexiones, fallos de búsqueda, cada evento de partida, victoria y derrota, saldo y misiones, y reinicia la demo. Para capturas, «Ocultar para capturas» lo quita del todo, o pon el atributo `PivotCapture = true` en Workspace.

## Arquitectura (`ReplicatedStorage.PivotUI`)

**Base**
- `Theme`: tokens de color, tipografía (Oswald, Builder Sans y Builder Mono, incluidas en el motor), tiempos de animación y medidas por formato (escritorio, tablet y móvil horizontal).
- `UI`: kit de componentes (botón con estados hover / pressed / selected / focused / disabled / loading, paneles con esquina cortada, etiquetas, barras, segmentados, interruptores, deslizadores, modal único con foco atrapado y avisos).
- `Icons`, `WeaponView`: atlas y «range card» con ViewportFrame (se gira arrastrando y aplica el acabado al modelo).
- `Util`: scopes de limpieza (conexiones, tareas, tweens, instancias), señales y formato.

**Datos y lógica**
- `Data/Catalog`, `Data/World`: fuente única de armas, cosméticos, modos, mapas, amigos, misiones y novedades.
- `State`: estado de sesión y reglas (sin compras duplicadas, reclamar una sola vez, pagar una vez por partida).
- `Sim`: backend simulado y reproducible (grupo, invitaciones, matchmaking con id, red).
- `Match/Engine`: partida simulada con semilla y un guion reproducible. `Match/Stage`: cámara, arma en primera persona, figura objetivo, espectador y calidad gráfica.

**Pantallas y cliente**
- `Screens/*`: Boot (precarga real con alternativa si algo falla), Title, Lobby (barra superior, navegación, introducción, guardas), Matchmaking, Tabs (Inicio, Jugar, Arsenal, Tienda, Misiones, Perfil, Ajustes), Match (HUD) y Results.
- `Showcase`: el panel de demostración.
- `StarterPlayerScripts.PivotClient`: ScreenGuis, formato según tamaño, router por fase, ajustes, red e input global. Incluye `PivotDevBridge`, un BindableFunction local para pruebas automáticas y capturas.

Cada pantalla recibe un scope: al cambiar de pantalla se cierran sus conexiones y tareas.
En la prueba, 21 cambios de pestaña dejaron las mismas 11 escuchas y 459 instancias.

## Flujos comprobados en Play Mode (13/11/2026)

- **A**: entrada → lobby → jugar → listo → buscar → partida encontrada → aceptar → carga del mapa → HUD → muerte / reaparición → puntuaciones → victoria → resultados (+260 créditos, sube a nivel 7, misiones +1) → lobby. Pagar dos veces la misma partida queda bloqueado.
- **B**: tienda → Wasp SMG → confirmar (tres Intro rápidos dan **una** compra, comprobante PV-1001, saldo 3.200 → 1.400) → equipar → aparece en el lobby (soporte 3D) y en el equipamiento.
- **C**: misión «Consigue 10 eliminaciones» → reclamar (+250 XP y +200 créditos) → un segundo intento se rechaza.
- **D**: ajustes → cambiar la mira → salir avisa de cambios sin aplicar → aplicar → reabrir conserva el valor.
- **E**: caducidad al aceptar, cancelación de búsqueda, desconexión simulada y repetición del ciclo sin pantallas ni recompensas duplicadas.
- Formatos: escritorio y tablet (1400×580 dentro de Studio) y móvil horizontal (iPhone 14, 844×390, con controles táctiles).

## Pendiente (real)

- **Modelos reales.** Pistol (Tern P9), Rifle (Kite C7), Shotgun (Anvil 12) y AmmoBox (caja de munición) siguen sin importarse en Studio, porque el MCP no tenía permiso de subida. Hasta entonces se ven como «Modelo pendiente». Los FBX están en `../3D-Models/Roblox_Props_Portfolio/export/`. Al importarlos, cada uno debe quedar con el nombre `Rifle` / `Shotgun` / `Pistol` / `AmmoBox` dentro de `ReplicatedStorage.PivotUI.Assets.Weapons`, con el largo en X (boca hacia +X) y `Paint = true` en las piezas pintadas.
- Wasp SMG, Lance DMR y el botiquín son **sustitutos provisionales** hechos con Parts, y así se marcan en la UI.
- **Capturas.** Faltan las capturas finales a 1920×1080. El método está probado: salida virtual de Hyprland 2560×1600, simulador «HD 1080» en ActualResolution y recorte en (231, 331).
- Textos solo en español. No hay soporte de mando (no se anuncia).
- El place nunca llegó a guardarse desde Studio. `place/PIVOT_ShooterUI.rbxl` se reconstruyó a partir de la copia automática de las 12:05 más los cambios posteriores (`tools/reapply_1205.py`). Los scripts están verificados ida y vuelta; queda pendiente abrirlo en Studio para confirmarlo.
