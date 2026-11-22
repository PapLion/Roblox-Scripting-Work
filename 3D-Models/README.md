# Modelos 3D (Blender)

Modelos propios hechos en Blender. Cada carpeta trae los `.blend` editables, los scripts que los generan y los renders de presentación.

| Carpeta | Contenido |
|---|---|
| `Roblox_Props_Portfolio/` | Props listos para Roblox: armas RPG y de shooter (Pistol, Rifle, Shotgun, AmmoBox…), personajes, vehículo y mobiliario urbano. `blend/` (escena `Assets` = originales exportables, `Showcase` = estudio), `export/<Asset>/<Asset>.fbx` con `export_manifest.json` y `verify_report.txt`, `scripts/` generadores, `renders/`. El detalle está en su README. |
| `Neo_Characters/` | Nix, Yoru y Akemi, personajes esféricos estilizados del proyecto Neo. Incluye `Neo_Characters.blend`, las copias `backups/` v1–v4, `build_scripts/` (orden de construcción en su README) y `renders/` (v2–v5). |

**Qué no se incluye**
- Los archivos de referencia oficiales de Roblox (`BlockyCharacter.fbx`, `ClassicMannequin.fbx`): se descargan desde la documentación de creadores de Roblox.
- Las imágenes de referencia sueltas.

**Relación con PIVOT:** los FBX de `Roblox_Props_Portfolio/export/` (Pistol, Rifle, Shotgun, AmmoBox) son las armas que usa la UI de `../PIVOT-Shooter-UI`. Faltan por importar en Studio; los pasos están en su README.
