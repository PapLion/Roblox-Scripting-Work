# PIVOT · UI de shooter competitivo en Roblox Studio

Proyecto personal de portafolio: un sistema completo de interfaz para un shooter competitivo,
hecho con ScreenGuis nativas y Luau, con datos simulados y un recorrido jugable en Play Mode.
No es un shooter real. El grupo, el matchmaking, la tienda, la red y las partidas se simulan
en el cliente, sin servidores, sin DataStore y sin compras reales (no usa MarketplaceService).

## Contenido

| Carpeta | Qué hay |
|---|---|
| `place/` | Copias locales del place. La versión al día es la experiencia privada «UI» en Roblox (ver Pendiente) |
| `src/` | Todos los scripts, con la misma jerarquía que en Studio (`*.module.luau`, `*.client.luau`) |
| `art/` | Atlas de UI propio (76 iconos, emblemas, piezas 9-slice y efectos de HUD), su generador y su mapa |
| `tools/` | Extractor y parcheador de `.rbxl`, y el script de recuperación de la sesión del 13/11 |
| `captures/` | 12 capturas a 1920×1080 reales del recorrido completo, más `components/` (láminas de componentes renderizadas en Studio con el módulo `UI`) y `responsive/` (tablet y móvil en modo táctil) |

## Abrir y probar

1. Abre `place/PIVOT_ShooterUI.rbxl` en Roblox Studio.
2. Pega una vez `tools/post_recovery_fixups.luau` en la barra de comandos (ajustes del decorado posteriores a la copia automática).
3. El atlas está subido como recurso privado (`Icons.uploaded = rbxassetid://112649700257332`) y los cuatro modelos importados también. Desde otra cuenta no cargan: sube `art/pivot_atlas.png` y los FBX y cambia los ids.
4. Pulsa Play. El recorrido entero se hace con los botones normales.

**Teclado**
- Lobby: Q / E cambian de sección, las flechas e Intro navegan con foco visible y Retroceso cierra los diálogos (Escape está reservado por Roblox).
- Partida: clic o Espacio dispara, clic derecho apunta, R recarga, 1 / 2 o la rueda cambian de arma, G usa el apoyo, Tab (mantener) abre las puntuaciones y P pausa.

**Pruebas y capturas:** en Studio el cliente crea `PlayerGui.PivotDevBridge` (un BindableFunction local que no existe fuera de Studio). Con él se leen el estado y se disparan acciones y eventos de partida para recorrer los flujos y preparar capturas reproducibles.

## Arquitectura (`ReplicatedStorage.PivotUI`)

**Base**
- `Theme`: tokens de color, tipografía (Highway Gothic para rótulos, Special Elite para el papel impreso, Builder Sans y Builder Mono para texto; todas incluidas en el motor), tiempos de animación y medidas por formato (escritorio, tablet y móvil horizontal).
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
- `StarterPlayerScripts.PivotClient`: ScreenGuis, formato según tamaño, router por fase, ajustes, red e input global. Incluye `PivotDevBridge` (solo en Studio) para pruebas automáticas y capturas.

Cada pantalla recibe un scope: al cambiar de pantalla se cierran sus conexiones y tareas.
En la prueba, 21 cambios de pestaña dejaron las mismas 11 escuchas y 459 instancias.

## Flujos comprobados en Play Mode (13/11/2026)

- **A**: entrada → lobby → jugar → listo → buscar → partida encontrada → aceptar → carga del mapa → HUD → muerte / reaparición → puntuaciones → victoria → resultados (+260 créditos, sube a nivel 7, misiones +1) → lobby. Pagar dos veces la misma partida queda bloqueado.
- **B**: tienda → Wasp SMG → confirmar (tres Intro rápidos dan **una** compra, comprobante PV-1001, saldo 3.200 → 1.400) → equipar → aparece en el lobby (soporte 3D) y en el equipamiento.
- **C**: misión «Consigue 10 eliminaciones» → reclamar (+250 XP y +200 créditos) → un segundo intento se rechaza.
- **D**: ajustes → cambiar la mira → salir avisa de cambios sin aplicar → aplicar → reabrir conserva el valor.
- **E**: caducidad al aceptar, cancelación de búsqueda, desconexión simulada y repetición del ciclo sin pantallas ni recompensas duplicadas.
- Formatos: escritorio (1920×1080), tablet (999×626 y 1400×580 dentro de Studio) y móvil horizontal (844×390). En tablet la barra superior muestra solo iconos salvo la sección actual, los huecos de equipamiento estrechos quitan la miniatura y los textos secundarios se acortan en vez de cortarse; un escaneo de `TextFits` en todas las pestañas deja solo los recortes previstos (nombres muy largos y descripciones limitadas a dos líneas).

## Estado y pendiente (real)

- **Modelos.** Tern P9, Kite C7, Anvil 12 y la caja de munición son los FBX propios importados y normalizados (boca hacia +X, pivote centrado, `Paint` solo en las piezas pintadas): ids 88606029231934, 105588646967922, 128212766672588 y 98721329556482. Wasp SMG, Lance DMR y el botiquín están hechos en Studio con Parts; su longitud está medida del modelo.
- **Capturas.** Hechas, en `captures/` (01–11 más la confirmación de compra, las dos láminas de componentes y tres vistas responsive). La barra superior de Roblox (logo, menú y micrófono) aparece arriba a la izquierda: Studio no permite ocultarla.
- **Copia local del place.** El trabajo se guardó en la experiencia privada «UI» (place 138260939884345). Los `.rbxl` de `place/` son anteriores: para actualizarlos, en Studio *File > Save to File As* sobre `place/PIVOT_ShooterUI_laptop.rbxl`.
- Textos solo en español. No hay soporte de mando (no se anuncia).
