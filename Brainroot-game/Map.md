# Drive System - Necesary directory tree

## Van Model

TREE 1 - MODELO VAN (Workspace.Scene.Van)
==========================================
Es el modelo 3D de la van. Tiene 4 ruedas (a, b, c, d) y un cuerpo (body).
Cada rueda tiene 2 MeshParts. El cuerpo tiene 11 MeshParts.
Total: 19 MeshParts.

Workspace
└── Scene
    └── Van
        └── RootNode
            ├── a
            │   ├── a_Material.003_0_Node
            │   │   └── a_Material.003_0
            │   └── a_Material.005_0_Node
            │       └── a_Material.005_0
            ├── b
            │   ├── b_Material.003_0_Node
            │   │   └── b_Material.003_0
            │   └── b_Material.005_0_Node
            │       └── b_Material.005_0
            ├── body
            │   ├── body_Material.001_0_Node
            │   │   └── body_Material.001_0
            │   ├── body_Material.002_0_Node
            │   │   └── body_Material.002_0
            │   ├── body_Material.003_0_Node
            │   │   └── body_Material.003_0
            │   ├── body_Material.004_0_Node
            │   │   └── body_Material.004_0
            │   ├── body_Material.005_0_Node
            │   │   └── body_Material.005_0
            │   ├── body_Material.006_0_Node
            │   │   └── body_Material.006_0
            │   ├── body_Material.007_0_Node
            │   │   └── body_Material.007_0
            │   ├── body_Material.008_0_Node
            │   │   └── body_Material.008_0
            │   ├── body_Material.009_0_Node
            │   │   └── body_Material.009_0
            │   ├── body_Material.010_0_Node
            │   │   └── body_Material.010_0
            │   └── body_Material.011_0_Node
            │       └── body_Material.011_0
            ├── c
            │   ├── c_Material.003_0_Node
            │   │   └── c_Material.003_0
            │   └── c_Material.005_0_Node
            │       └── c_Material.005_0
            └── d
                ├── d_Material.003_0_Node
                │   └── d_Material.003_0
                └── d_Material.005_0_Node
                    └── d_Material.005_0

## Boton de activacion

TREE 2 - BOTÓN DE ACTIVACIÓN (Workspace.base 4.button)
=======================================================
Es el botón que el jugador clickea para entrar a la van.
Tiene 3 MeshParts: base, button1, button2.
Al hacer clic, teletransporta al jugador al asiento del Van.

Workspace
└── base 4
    └── button
        ├── base
        ├── button1
        └── button2

## Scritps del sistema de van

TREE 3 - SCRIPTS DEL SISTEMA
============================
- VanServerManager (ServerScriptService): Script del servidor. Crea el asiento, detecta clics del botón, recibe inputs del cliente y mueve el Van.
- VanClientHandler (StarterPlayerScripts): Script del cliente. Detecta cuando el jugador está sentado, muestra la UI de controles WASD y envía inputs al servidor.
- VanInput (ReplicatedStorage.Events): RemoteEvent para comunicación cliente-servidor. Se crea dinámicamente al iniciar el juego.

ServerScriptService
└── VanServerManager

StarterPlayer
└── StarterPlayerScripts
    └── VanClientHandler

ReplicatedStorage
└── Events
    └── VanInput (RemoteEvent - se crea dinámicamente)

## Gasolina

Workspace
└── Model - Gasolina (Model)
    ├── Model (Model) - 6 Parts internos
    ├── Model (Model) - 6 Parts internos
    └── 14 Parts (Part) - Partes directas del modelo

    