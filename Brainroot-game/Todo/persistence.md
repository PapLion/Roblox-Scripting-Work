Perfecto, vamos directo y claro:

---

# 🟢 SISTEMAS PERSISTENTES (SE GUARDAN)

Estos deben guardarse sí o sí:

### 💰 Cash System

✔ Dinero del jugador

### ⛽ Speed + Fuel + Carry System

✔ Speed level
✔ Fuel capacity *(no fuel actual, solo capacidad)*
✔ Carry capacity

### 📦 Delivery / Brainrot System

✔ Brainrots obtenidos

### ⭐ Star Level / Progression

✔ Nivel de estrellas

### 🌍 Zones System

✔ Zonas desbloqueadas *(o derivado del star level)*

### 🏠 Base System

✔ Base asignada
✔ Upgrades de la base
✔ Brainrots colocados en la base

---

# 🟡 SEMI-PERSISTENTE (DEPENDE, PERO RECOMENDADO NO GUARDAR EN MVP)

### ⛽ Fuel actual

❌ No guardar (mejor resetear a full al entrar)

### 📦 Paquetes en mano

❌ No guardar (puede romper el loop)

---

# 🔴 NO PERSISTENTE (NO SE GUARDA)

### 🚗 Driving System

❌ Movimiento
❌ Cámara
❌ Input
❌ Estado de conducción

---

### 👤 NPC System

❌ Estados (greeting, waiting, cooldown, etc.)
❌ NPCs activos
❌ comportamiento temporal

---

### 🎰 RNG (Bad NPC / robos / rewards temporales)

❌ No guardar eventos momentáneos

---

# 🧠 RESUMEN SIMPLE

```text
Se guarda:
- progreso
- recursos
- upgrades
- ownership (brainrots/base)

NO se guarda:
- estado momentáneo
- inputs
- interacción en tiempo real
```

---

Con esto ya tienes exactamente lo que el cliente quiso decir con:

> "VERY IMPORTANT MAKE IT SO EVERYTHING SAVES"

Pero traducido correctamente a dev:

👉 **“Todo lo importante para el progreso del jugador se guarda”** 😈
