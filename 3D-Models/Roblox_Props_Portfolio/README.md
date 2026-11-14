# Roblox Props Portfolio — RPG + Shooter + Personajes y vehículos + Props urbanos

Muestras de portafolio de modelos originales de armas, herramientas y props pensados para Roblox.
Son trabajo personal, no encargos de clientes. Se modelaron en Blender 5.2.3 mediante scripts
reproducibles (`scripts/`).

## Estructura

```
Roblox_Props_Portfolio/
├── blend/Roblox_Props_Portfolio.blend   archivo editable completo
├── export/<Asset>/<Asset>.fbx           una exportación por modelo
│   ├── export_manifest.json             dimensiones, triángulos, piezas, pivotes y materiales
│   └── verify_report.txt                resultado de la reimportación de prueba
├── renders/<pieza>/<pieza>_<vista>.png  renders finales (2048×2048; conjuntos 3072×2048)
└── scripts/                             generadores, presentación, render y exportación
```

**Escenas del .blend**
- `Assets`: los modelos limpios que se exportan. Hay una colección por asset con un empty raíz en el pivote.
- `Showcase`: estudio reutilizable con ciclorama, 4 luces de área, 2 softboxes de reflejo, sonda esférica
  y mundo en degradado. Cada toma es un fotograma de la línea de tiempo: un marcador de cámara selecciona
  la cámara, y la pose y la visibilidad de las instancias están en keyframes. Moverse por la línea de
  tiempo reproduce cada imagen exacta.
  - 1–2: conjunto RPG
  - 10–65: piezas RPG
  - 100–101: conjunto shooter
  - 110–145: piezas shooter
  - 200–246: personajes, enemigos y vehículos
  - 300–357: props urbanos y de tienda (357 = productos de la estantería)
  - 370: escena de esquina urbana (3072×2048)

  Los assets solo aparecen ahí como instancias de colección; la geometría no se toca.

## Assets

Medidas reales en metros (X × Y × Z, tal como se reimportan del FBX). Los triángulos son los del FBX
exportado (triangulado). Cada pieza tiene **un solo material**; en Roblox, cada pieza se importa como
una MeshPart independiente.

| Asset | FBX | Medidas (m) | Tris | Piezas | Pivote |
|---|---|---|---|---|---|
| Hacha de leñador | `Axe/Axe.fbx` | 0.247 × 0.055 × 0.842 | 2.474 | 5 | centro del agarre de cuero |
| Espada de aventurero | `Sword/Sword.fbx` | 0.226 × 0.038 × 0.976 | 3.018 | 6 | centro de la empuñadura |
| Martillo de herrero | `Hammer/Hammer.fbx` | 0.195 × 0.062 × 0.414 | 1.378 | 6 | zona de agarre |
| Pico de minería | `Pickaxe/Pickaxe.fbx` | 0.495 × 0.062 × 0.815 | 2.232 | 6 | agarre inferior |
| Escudo redondo | `Shield/Shield.fbx` | 0.612 × 0.096 × 0.612 | 3.340 | 6 | centro del asa trasera |
| Daga | `Dagger/Dagger.fbx` | 0.097 × 0.031 × 0.345 | 2.112 | 6 | centro de la empuñadura |
| Funda de daga | `Dagger_Sheath/Dagger_Sheath.fbx` | 0.052 × 0.019 × 0.214 | 570 | 2 | mismo pivote que la daga (pivotes juntos = daga envainada) |
| Pistola semiautomática | `Pistol/Pistol.fbx` | 0.220 × 0.033 × 0.150 | 3.654 | 7 | centro de la empuñadura |
| Rifle de asalto compacto | `Rifle/Rifle.fbx` | 0.749 × 0.059 × 0.257 | 5.186 | 12 | centro del pistolete |
| Escopeta de corredera | `Shotgun/Shotgun.fbx` | 0.998 × 0.066 × 0.148 | 6.344 | 12 | muñeca de la culata |
| Caja de munición | `AmmoBox/AmmoBox.fbx` | 0.307 × 0.144 × 0.190 | 1.768 | 8 | centro de la base |

**Orientación**
- RPG: eje largo +Z (hacia la cabeza o la punta), filo/cara de golpe hacia +X, grosor en Y.
- Shooter: cañón hacia +X, arriba +Z, lado izquierdo del arma en +Y.
- El FBX se exporta con −Z adelante / Y arriba, que es el estándar de Blender para FBX.

### Piezas animables (shooter)

Cada pieza es un objeto independiente con el origen en su eje real. No se modelan mecanismos internos.

| Asset | Piezas | Movimiento previsto |
|---|---|---|
| Pistola | `Pistol_Slide` (+ hijo `Pistol_SightDot`), `Pistol_Barrel`, `Pistol_Magazine`, `Pistol_Trigger`, `Pistol_Frame` | corredera: traslación −X · gatillo: giro en su pivote superior · cargador: sale por la empuñadura |
| Rifle | `Rifle_Bolt` (+ hijo `Rifle_BoltKnob`), `Rifle_Magazine`, `Rifle_Trigger`, `Rifle_Selector`, `Rifle_Upper`, `Rifle_Lower`, `Rifle_Furniture`, `Rifle_Barrel` (+ `Rifle_SightDot`), `Rifle_ButtPad` | cerrojo con palanca: traslación −X por la ventana de expulsión · selector: giro en su eje |
| Escopeta | `Shotgun_Pump`, `Shotgun_Bolt`, `Shotgun_Trigger`, `Shotgun_Receiver`, `Shotgun_Barrel` (+ `Shotgun_Bead`), `Shotgun_Stock`, `Shotgun_TriggerGroup`, `Shotgun_Shells` (+ `Shotgun_ShellBrass`), `Shotgun_ButtPad` | corredera delantera: traslación ±X · cerrojo: traslación −X |
| Caja | `AmmoBox_Lid` (+ hijos `AmmoBox_Handle`, `AmmoBox_HandleBrackets`), `AmmoBox_Latch`, `AmmoBox_Body`, `AmmoBox_Hinge`, `AmmoBox_Stripe`, `AmmoBox_Label` | tapa: giro en el eje de la bisagra · cierre: giro en su eje inferior · asa: giro en los soportes |

## Personajes, enemigos y vehículos

Todas estas piezas apoyan en el suelo: el origen está en la base, a nivel del suelo, y el frente mira
hacia **−Y** en Blender (lo mismo que en el FBX con −Z adelante). **La orientación final en Roblox no
está comprobada;** si el modelo aparece de espaldas, hay que girarlo 180° al importarlo.

| Asset | FBX | Medidas (m) X × Y × Z | Tris | Piezas |
|---|---|---|---|---|
| Guardia humanoide | `Guard/Guard.fbx` | 1.170 × 0.543 × 1.684 | 12.854 | 35 mallas + armature R15 oficial (51 huesos): 15 partes del cuerpo oficial de Roblox + 20 piezas del uniforme |
| Boss slime | `SlimeBoss/SlimeBoss.fbx` | 1.720 × 1.351 × 1.281 | 7.402 | 6 (cuerpo con gotas, ojos, brillos, boca, corona, gemas) |
| Esqueleto | `Skeleton/Skeleton.fbx` | 0.612 × 0.313 × 1.412 | 18.390 | 23 (15 partes R15 + mandíbula, cuencas, grieta, ojos brillantes, núcleo, cinturón, tela, hombrera de láminas) |
| Espada oxidada | `Skeleton_Sword/Skeleton_Sword.fbx` | 0.146 × 0.042 × 0.629 | 364 | 2 · pivote en la empuñadura |
| Rodela rota | `Skeleton_Buckler/Skeleton_Buckler.fbx` | 0.350 × 0.072 × 0.350 | 1.682 | 3 (madera, herrajes + remaches, juntas de tablas) · pivote en el asa |
| Coche compacto | `Car/Car.fbx` | 1.820 × 3.756 × 1.484 | 25.156 | 26 |
| Montura jabalí | `BoarMount/BoarMount.fbx` | 0.992 × 2.017 × 1.179 | 26.334 | 27 |

**Revisión de calidad (v2).** Estas piezas y las tres armas de fuego se rehicieron o pulieron
conservando su diseño: sin límite uniforme de triángulos, con más geometría solo donde mejora la
silueta o el detalle visible.
- Jabalí: cuerpo con cruz, papada y morro en cuña; crin de cerdas, cejas, orejas con interior, pezuñas
  partidas con espolones; silla con pomo, faldones, costuras y remaches; manta con ribete; petate.
- Slime: rehecho como gota de gelatina sencilla con ojos, boca y la corona rota hundida en la punta.
- Guardia: construido sobre el personaje oficial de Roblox (ver más abajo).
- Esqueleto: huesos con cóndilos, costillas abiertas hacia el esternón, vértebras con apófisis, pelvis
  con alas ilíacas, hombrera de láminas remachada, rodela con tablas y remaches.
- Coche: carrocería con más curvatura, molduras de paso de rueda, llantas de radios con disco y pinza,
  faros con bisel y proyectores, antinieblas, limpiaparabrisas, marcos de ventanilla, escape.
- Armas: culatas y empuñaduras con volumen redondeado ("pillow"), garganta y picado en la escopeta,
  carrillera en el rifle, texturizado y estrías delanteras en la pistola, pasadores y botones.

### Qué está preparado y qué falta

| Asset | Preparado | No incluido / faltaría |
|---|---|---|
| Guardia | **Cuerpo, cabeza dinámica y rig son los oficiales de Roblox** (`BlockyCharacter.fbx`, archivos de referencia del Creator Hub de Roblox: create.roblox.com → Avatar → Character bodies → Project files). Armature R15 de 51 huesos (incluye los huesos faciales FACS de la cabeza dinámica) con las 15 partes pesadas a su hueso. El uniforme es original (yelmo con penacho, peto con emblema, hombreras, cinturón, hebilla y bolsa, brazales, polainas, capa, bufanda, rasgos de la cara) y cada pieza está pesada al 100 % a su hueso, así que sigue al rig. Escala: 1 stud = 0,28 m. | Sin animaciones propias. No se incluyen los Attachments ni las jaulas de ropa por capas de la plantilla (se pueden recuperar del archivo oficial en `reference/roblox_official/`). Falta comprobar la importación como avatar/NPC en Roblox Studio. |
| Esqueleto | 15 partes R15 con pivotes en las articulaciones (segmentado, sin armature). La mandíbula es una pieza separada con pivote en la bisagra. Espada y rodela son assets aparte, colocados en las manos solo en la escena. | Sin rig, sin uniones ni animaciones (a diferencia del guardia). Habría que crear los Motor6D o usar un rig R15 y soldar las armas a las manos (Weld o Motor6D). |
| Boss slime | Cuerpo de una sola malla; ojos, brillos, boca y corona van como objetos separados (se podrían mover por separado). | Sin rig, sin blendshapes y sin deformación de "gelatina". La animación tendría que hacerse con huesos o escalados en Roblox. |
| Coche | 4 ruedas separadas (`Car_Wheel_FL/FR/RL/RR`, con llanta y tapacubos como hijos) con el **pivote en el buje** y eje de giro X. El volante es pieza propia con pivote en su centro. Lleva interior básico: salpicadero, asientos, moqueta, paneles de puerta y consola. | Las puertas, el capó y el portón **no son piezas separadas**. Sin chasis físico, constraints, sistema de conducción ni colisiones. Cristales: color con alfa 0,32 en el FBX; en Roblox hay que ajustar la Transparency de la MeshPart. |
| Jabalí | 4 patas separadas (`BoarMount_Leg_FL/FR/RL/RR`, con la pezuña como hijo) con pivote en hombro o cadera. Silla, manta, arnés, cabezada, riendas y estribos son piezas propias. **Punto de asiento: (0, 0.05, 0.991) m** respecto al origen (propiedad `seat_point` del empty raíz). | Cabeza y cuerpo forman una sola malla; las patas son de una pieza (sin rodilla articulada); sin rig ni animaciones. Habría que añadir el Seat y la lógica de montura en Roblox. |

El maniquí gris R6 (`Mannequin_R6`) sirve solo para el render de escala de la montura y no se exporta.

## Props urbanos y de tienda

Assets de entorno para ciudades, calles, tiendas e interiores (fotogramas 300–370). Frente hacia −Y.
Las cifras son las del FBX reimportado.

| Asset | FBX | Medidas (m) X × Y × Z | Tris | Piezas | Pivote |
|---|---|---|---|---|---|
| Máquina expendedora (marca ficticia QUENCHO) | `VendingMachine/VendingMachine.fbx` | 0.955 × 0.818 × 1.850 | 21.478 (7.898 + 13.580 del stock horneado) | 19 | centro inferior de la **cara trasera** (se encaja contra la pared) |
| Contenedor de basura | `Dumpster/Dumpster.fbx` | 1.439 × 1.149 × 1.241 | 10.404 | 14 | centro de la base |
| Banco de parque | `Bench/Bench.fbx` | 1.800 × 0.609 × 0.891 | 8.484 | 6 | centro de la base |
| Farola | `StreetLamp/StreetLamp.fbx` | 0.464 × 1.752 × 4.632 | 5.494 | 5 | centro de la base |
| Aire acondicionado exterior | `ACUnit/ACUnit.fbx` | 0.974 × 0.419 × 1.005 | 9.372 | 11 | **plano de la pared** (y = 0), base de los soportes |
| Estantería (solo estructura) | `Shelf/Shelf.fbx` | 1.016 × 0.494 × 2.000 | 5.664 | 13 | centro inferior de la cara trasera |
| Estantería con stock | `Shelf_Stocked/Shelf_Stocked.fbx` | 1.016 × 0.494 × 2.000 | 32.768 | 22 | igual |
| Lata | `Product_Can/Product_Can.fbx` | 0.067 × 0.067 × 0.121 | 508 | 3 | centro de la base |
| Botella | `Product_Bottle/Product_Bottle.fbx` | 0.069 × 0.069 × 0.230 | 596 | 3 | centro de la base |
| Caja alta | `Product_BoxTall/Product_BoxTall.fbx` | 0.190 × 0.070 × 0.270 | 524 | 3 | centro de la base |
| Caja de snack | `Product_BoxSmall/Product_BoxSmall.fbx` | 0.142 × 0.098 × 0.080 | 124 | 2 | centro de la base |

**Piezas separadas y móviles**
- Máquina: `VendingMachine_Flap` (trampilla de recogida, pivote en su bisagra superior), cristal
  (`_Glass`, separado), luz y rótulo emisivos (`_Glow`), botonera y ranuras. Los productos se ven tras el
  cristal; no hay mecanismo interno modelado.
- Contenedor: `Dumpster_Lid` (pivote en el eje de las bisagras traseras), 4 ruedas
  `Dumpster_Wheel_FL/FR/BL/BR` (pivote en el eje, con el tapacubos como hijo), herrajes, pedales de freno.
  Desgaste ligero solo en la capa de presentación (oclusión en pliegues y decoloración suave).
- Banco: `Bench_Frame_L/R` (fundición), `Bench_Rail`, listones de asiento y respaldo, tornillos.
  `seat_points` en el empty raíz: dos plazas a (±0.42, −0.07, 0.44) m.
- Farola: base, poste con brazo, cabeza, herrajes (anclajes, collarines, trampilla) y el difusor emisivo
  como pieza propia (`StreetLamp_Diffuser`).
- Aire acondicionado: `ACUnit_Fan` (pivote en el eje, gira sobre Y), rejilla, embocadura, aletas
  traseras, soportes de pared, tacos de goma, tuberías y aislamiento, placa.
- Estantería: módulo con montantes ranurados, panel trasero, zócalo y **4 baldas desmontables**
  (`Shelf_Board_1…4`, origen en el borde trasero de cada balda para recolgarla a otra altura).

**Reutilización de productos**
- En el `.blend`, los productos de la estantería y de la máquina son **instancias de colección**
  (58 y 25): no hay geometría duplicada.
- Las variantes de color (`Product_Can_Orange`, `Product_Bottle_Juice`, `Product_BoxTall_Blue`)
  **reutilizan la misma malla** con un material distinto a nivel de objeto. En Roblox equivalen a la
  misma MeshPart con otro color, por eso no se exportan aparte.
- Para la exportación, `export_fbx.py` hornea el stock instanciado en una malla por material
  (`VendingMachine_Stock_*`, `Shelf_Stock_*`). La estantería se entrega en dos versiones: solo
  estructura (para rellenarla con los productos sueltos) y con stock.

**Escena de demostración** (`renders/urban_scene/urban_corner_scene.png`): solo estos props, un suelo de
baldosas con bordillo y dos paredes lisas, con un maniquí R6 gris de 1,50 m como referencia de escala
(`Mannequin_R6_Standing`, solo presentación, no se exporta).

## Materiales (valores exportados)

Son materiales Principled con color plano (sRGB), sin texturas.

| Material | Color | Metálico | Rugosidad | Uso |
|---|---|---|---|---|
| M_Steel | #8E99A8 | 1 | 0.30 | acero gris azulado |
| M_SteelDark | #646C78 | 1 | 0.40 | herrajes, cuñas, langets |
| M_Gunmetal | #4A515B | 1 | 0.36 | correderas, receptores |
| M_Wood | #87573A | 0 | 0.58 | madera cálida |
| M_Leather | #3B261B | 0 | 0.62 | cuero oscuro |
| M_Polymer | #2C3035 | 0 | 0.58 | polímero negro |
| M_Polymer_Tan | #A08763 | 0 | 0.60 | guardamanos/culata del rifle, etiqueta |
| M_Rubber | #1C1E21 | 0 | 0.80 | cantoneras |
| M_Brass / M_Copper | #C39A4C / #B86E45 | 1 | 0.32 / 0.34 | acentos metálicos |
| M_Paint_Red / Amber / Teal / Orange / OD | #A8352C / #D9982C / #2E8A84 / #E2702B / #56603F | 0 (OD 0.25) | 0.42–0.50 | acentos de identidad y pintura de la caja |
| M_Gem_Blue / M_Gem_Green | #2F6FD6 / #2FA56E | 0 | 0.10 | gemas |
| M_Shell_Red | #B23A2E | 0 | 0.40 | cartuchos |
| M_Skin / M_Face / M_Eye_White | #E9B98F / #231C1C / #F4F1EA | 0 | 0.25–0.55 | piel y rasgos |
| M_Cloth_Blue / Gray / Cream | #3D5E9C / #4B505B / #DCCFB2 | 0 | 0.75–0.80 | ropa del guardia |
| M_Slime / M_Slime_Dark / M_Gold / M_Gem_Red | #5ED66E / #1F4A2B / #E3B23C / #D3344A | 0 / 0 / 1 / 0 | 0.10–0.40 | slime y corona |
| M_Bone / M_Bone_Dark / M_Glow / M_Rust | #E3D8BE / #3A302A / #FF7A3A (emisivo) / #6E4630 | 0 / 0 / 0 / 0.45 | 0.40–0.78 | esqueleto y armas oxidadas |
| M_CarPaint / M_CarWhite / M_Glass / M_Chrome | #2C8C99 / #E7E8E4 / #A9CBD8 (alfa 0.32) / #C9CFD7 | 0.3 / 0 / 0 / 1 | 0.05–0.35 | carrocería, techo, cristal, cromados |
| M_HeadLight / M_TailLight / M_Seat / M_Interior | #F6F3E4 / #C42E2B / #3C4048 / #5B616B | 0 | 0.15–0.85 | luces e interior |
| M_Fur / M_Fur_Dark / M_Snout / M_Tusk / M_Hoof | #5B3E2C / #3A291E / #6E4A3E / #EEE4C9 / #2B2523 | 0 | 0.40–0.90 | jabalí |
| M_SlimeBlue / M_SlimeMouth | #3F8FE3 / #14304F | 0 | 0.10 / 0.30 | slime (subsurface y capa de barniz) |
| M_Vend_Red / M_Vend_Dark / M_Vend_Inner / M_LampGlow (emisivo) | #C73A35 / #26292E / #D6D9DC / #FFE3AE | 0 | 0.35–0.55 | máquina expendedora, luces |
| M_Bin_Green / M_Bin_Lid | #3E7A55 / #2F6044 | 0 | 0.50–0.55 | contenedor |
| M_Iron / M_WoodBench | #2E3533 / #9C6B45 | 0.6 / 0 | 0.45 / 0.55 | fundición, listones |
| M_AC_Shell / M_Shelf_White / M_Shelf_Accent | #E6E4DE / #E1E3E5 / #2F6FB5 | 0 / 0.2 / 0 | 0.40–0.45 | aire acondicionado, estantería |
| M_Alu / M_Label / M_GlassClear (alfa 0.14) | #C3C8CE / #F3F1EA / #D3E6EC | 1 / 0 / 0 | 0.04–0.50 | latas, etiquetas, cristal de la máquina |
| M_Prod_Yellow / Blue / Green / Pink / Purple | #F0BE2E / #2F73D0 / #45A863 / #E36A93 / #7656C4 | 0 | 0.30–0.42 | productos |

**Presentación frente a exportación**
- Para los renders, cada material lleva una capa procedural sutil marcada como `presentation`:
  - veta en la madera
  - variación de rugosidad en metal y pintura
  - micro-relieve en el cuero
- `export_fbx.py` elimina esa capa antes de exportar, así que los FBX contienen solo los valores planos
  de la tabla.
- Los materiales `PRES_*` (fondo, softbox, clay y líneas del wireframe) son solo del estudio y nunca
  se exportan.

## Exportación y verificación

- Formato FBX, en metros (escala 1.0), triangulado y suavizado por caras con normales personalizadas.
  Solo meshes: los empties raíz no se exportan. Se conserva la jerarquía entre piezas animables.
- El guardia se exporta con su armature (malla + huesos); el resto, solo meshes.
- Comprobado reimportando cada FBX en una escena vacía de Blender (`scripts/verify_fbx.py`, ver
  `export/verify_report.txt`). Las 29 exportaciones coinciden con el original (`ALL_OK=True`) en:
  - triángulos
  - dimensiones (±2 mm)
  - nombres de piezas
  - materiales y colores base
  - UVs
  - un material por pieza
  - número de huesos (guardia: 51)
  - pivotes y jerarquía (revisados en pistola, caja y hacha)
- **No se ha probado en Roblox Studio.** El formato FBX y la división en un material por pieza son los
  adecuados para el importador 3D de Roblox, pero la escala de importación (metros → studs; Roblox
  suele usar 1 stud ≈ 0,28 m) y si los colores del material se aplican o hay que asignarlos a mano a
  cada MeshPart deben comprobarse al importar.

## Renders (`renders/`)

Todos los renders son PNG con fondo e iluminación del mismo estudio. Las piezas de personajes y vehículos (fotogramas 200–246) apoyan en el suelo y sus vistas ortográficas van inclinadas unos 8° para que el suelo llene el borde inferior. Las imágenes técnicas llevan el
conteo real de triángulos.

| Pieza | Imágenes |
|---|---|
| `collection/` | `collection_beauty.png`, `collection_wireframe.png` (3072×2048) |
| `axe/`, `sword/`, `hammer/`, `pickaxe/`, `dagger/` | `_hero`, `_front`, `_side`, `_detail`, `_wireframe` |
| `shield/` | lo mismo, más `shield_back.png` (agarre y correa) |
| `shooter_collection/` | `shooter_collection_beauty.png`, `shooter_collection_wireframe.png` (3072×2048) |
| `pistol/`, `rifle/`, `shotgun/` | `_hero`, `_right`, `_left`, `_detail`, `_wireframe`, `_fpv` (primera persona, sin manos) |
| `ammobox/` | `_hero`, `_right` (cara del cierre), `_left` (cara de la bisagra), `_detail`, `_wireframe` |
| `guard/`, `slimeboss/`, `skeleton/` | `_hero`, `_front`, `_side`, `_back`, `_detail` (rostro), `_wireframe` |
| `car/` | lo mismo, más `car_interior.png` (desde la plaza trasera, con luz de cabina de presentación) |
| `boarmount/` | lo mismo, más `boarmount_scale.png` (maniquí R6 sentado; altura del asiento anotada) |
| `vendingmachine/`, `dumpster/`, `bench/`, `streetlamp/`, `acunit/`, `shelf/` | `_hero`, `_front`, `_side`, `_back`, `_detail`, `_wireframe` (el wireframe de máquina y estantería incluye los productos instanciados en el conteo) |
| `shelf/shelf_products.png` | los productos reutilizables y sus variantes de color |
| `urban_scene/urban_corner_scene.png` | escena de esquina urbana con todos los props (3072×2048) |

Notas sobre los encuadres:
- Las vistas frontal y lateral (RPG) y las laterales (shooter) son ortográficas. En las piezas RPG
  largas, el objeto va en diagonal dentro del marco cuadrado para aprovecharlo.
- La daga aparece junto a su funda en `dagger_hero` y `dagger_wireframe`.

`renders/_overview_rpg.png`, `_overview_shooter.png`, `_overview_chars.png` y `_overview_props.png` son hojas de contacto de revisión, no imágenes de portafolio.

Para volver a renderizar, por ejemplo los fotogramas 125 y 101:

```
scripts/render_batches.sh 125 101
```

## Scripts

| Script | Función |
|---|---|
| `lib.py` | utilidades de modelado y paleta de materiales |
| `m_*.py` | generadores de las piezas RPG |
| `s_*.py` | generadores de las piezas shooter |
| `c_*.py`, `v_car.py` | personajes, enemigos, montura y coche (`c_guard.py` importa la plantilla oficial de Roblox) |
| `p_*.py` | props urbanos, productos y maniquí de escala |
| `shots_chars_extra.py` | tomas de los props y de la escena urbana (lo ejecuta `shots.py`) |
| `finalize_uv.py` | UVs |
| `studio.py` | estudio |
| `shots.py` | cámaras, poses y línea de tiempo |
| `render_all.py`, `render_batches.sh` | render en segundo plano |
| `export_fbx.py`, `verify_fbx.py` | exportación y verificación |

Se ejecutan dentro de Blender con `exec(open("scripts/run.py").read()); build("m_axe")`.

## Limitaciones pendientes

- **Sin texturas:** solo color por pieza. Las UVs son un *Smart UV Project* automático, válido para
  texturizar más adelante, pero no están optimizadas ni empaquetadas para pintar a mano.
- **Vistas laterales largas:** en espada, rifle y escopeta salen finas dentro del formato cuadrado de
  2048×2048. Es inevitable si se quiere respetar ese formato.
- **Uniones internas intencionadas:** los mangos entran dentro de las cabezas y los cargadores dentro de
  sus alojamientos. No hay caras coplanares visibles ni parpadeo, pero las piezas no están unidas en una
  sola malla estanca.
- **Sin animaciones ni scripting:** solo están preparados los pivotes y la separación de piezas.
- **Conteos más altos tras la revisión de calidad:** jabalí 26.334, coche 25.156, máquina con stock
  21.478 y estantería con stock 32.768 triángulos en total. Están repartidos en muchas piezas y ninguna
  supera el límite de 20.000 por MeshPart de Roblox, pero son assets "hero"; para mapas grandes
  convendría crear LODs.
- **Sin verificar en Roblox:** escala, orientación final del Tool/Grip y aplicación de colores.
