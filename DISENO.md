# Funa Battle Royal — diseño y referencia

Arena brawler online de humor absurdo, hasta 10 jugadores (humanos + bots).
Godot 4.6, Forward+, física Jolt. Todos los personajes usan **nombres en clave**
y caras garabato: nunca nombres ni fotos reales.

## Cómo probar

| Qué | Cómo |
|---|---|
| Jugar solo contra 9 bots | Doble clic en `jugar_solo_con_bots.bat` |
| Dos ventanas online en la misma PC (+6 bots) | Doble clic en `probar_2_jugadores.bat` |
| Desde el editor | F5; en el lobby elegí personaje, bots y "Crear partida" |
| Verificar que todo carga | Correr la escena `tests/check_all.tscn` |
| Capturas automáticas | Correr `tests/screenshots.tscn` |

Atajos de prueba (solo el host, en builds de debug): **F1** bomba nuclear,
**F2** COVID, **F3** muerte por edad, **F4** apagón, **F5** hiperinflación,
**F6** lluvia de empanadas, **1–9** aparece un arma a tus pies.

## Controles

| Acción | Teclado y mouse | Mando |
|---|---|---|
| Moverse / cámara | WASD / mouse | Stick izquierdo / derecho |
| Saltar | Espacio | A |
| Ataque (mantener) | Click izquierdo | X o gatillo derecho |
| Golpe fuerte | Click derecho | Y |
| Habilidad | Q | RB |
| Agarrar arma | E | B |
| Soltar el mouse | Esc | — |

## Reglas de la partida

- **La Inflación** (la zona) se achica en 4 fases. Afuera se pierde 2 → 4 → 7 → 12 de vida por segundo.
- Gana el último vivo. Al terminar, todos vuelven al lobby solos a los 10 segundos.
- Más allá de la costa hay **tiburones** (muerte instantánea).
- Los **búnkeres** (3 en el mapa) reducen el daño de la bomba nuclear al 10%.

### Fórmula de daño

```
daño = base
     × daño del atacante (buffs: Complejo de Altura ×1.5)
     × rivalidad, si están a menos de 12 m (rivales ×1.2–1.25, aliados ×0.75–0.8)
     × daño recibido del objetivo (Huelga de Hambre ×0.2, Siesta ×0.5, Vacunado ×0.9)
Invulnerable → 0 · Inmune a distancia + proyectil → 0
```

Combo de golpes livianos: 3 golpes seguidos (menos de 0.9 s entre cada uno);
el tercero pega ×1.5 y empuja el doble. El golpe fuerte pega ×2.2 con más empuje,
pero tarda ×2.4.

## Personajes

| Personaje | País | Vida | Vel. | Habilidad (Q) | Tags |
|---|---|---|---|---|---|
| Lionel Pessi | Argentina | 90 | 7.2 | Gambeta: dash invulnerable | argentino |
| Javier Pilei | Argentina | 100 | 6.3 | ¡AFUERA!: embestida, 15 de daño y vuelo | argentino |
| Cristina Birchner | Argentina | 100 | 6.0 | Cadena Nacional: silencia y frena (9 m) | argentino |
| Mirta Legrande | Argentina | 75 | 4.8 | Almuerzo con Mirta: se cura | argentino, riesgo, edad |
| Donald Tromp | EE.UU. | 110 | 5.8 | El Muro: muro de 6 m por 8 s | nuclear, riesgo |
| Joe Bidet | EE.UU. | 100 | 5.2 | Siesta: duerme, se cura, mitad de daño | riesgo, edad |
| Smoke Dogg | EE.UU. | 95 | 6.2 | Nube Verde: marea y frena (5.5 m) | — |
| Elon Musgo | EE.UU. | 95 | 6.3 | Cohete a Marte: súper salto con golpe | — |
| Vladimir Pupin | Rusia | 105 | 6.0 | Té de Polonio: veneno 4/s por 6 s | nuclear |
| Kim Jong Dos | Corea del Norte | 115 | 5.5 | Misil de Prueba: explosión de 30 | nuclear |
| Xi Pingpong | China | 105 | 5.9 | Ping Pong: devuelve proyectiles | nuclear |
| AMLOL | México | 105 | 5.6 | Abrazos, no balazos: inmune a proyectiles | riesgo |
| Neymal | Brasil | 85 | 7.0 | Piscinazo: invulnerable + tarjeta amarilla | — |
| Napoleón Bonsái | Francia | 90 | 6.6 | Complejo de Altura: +50% daño | — |
| Albert Zweistein | Alemania | 90 | 5.8 | Relatividad: enemigos 60% más lentos | — |
| Mahatma Gandy | India | 95 | 5.8 | Huelga de Hambre: sin atacar, -80% daño | nuclear |

## Armas

DPS = daño por segundo atacando sin parar (sin combos ni buffs).

| Arma | Tipo | Daño / cadencia | DPS | Usos | Arma firma |
|---|---|---|---|---|---|
| Puños | Cuerpo a cuerpo | 6 / 0.45 s | 13 | ∞ | — |
| Motosierra (legendaria) | Cuerpo a cuerpo | 4 / 0.15 s | 27 | 120 | **Pilei**: +50% y "recorte" (sangrado). Otros: -25% y van más lento |
| El Puro (épica) | Aros de humo | 9 / 0.5 s | 18 | 30 | **Smoke Dogg**: puntería perfecta, +30%. Otros: **se marean** (pantalla ondulada) |
| La Chancla (rara) | Se tira, aturde | 11 / 0.8 s | 14 | ∞ | **Mirta**: +60% y chanclazo de 1 s |
| No-Es-Un-Lanzallamas (épica) | Cono 5.5 m, quema | 3 / 0.1 s | 30 | 60 | **Elon**: +30% daño y alcance. Otros: -20% |
| Bate de Béisbol | Cuerpo a cuerpo, empuja | 12 / 0.75 s | 16 | 40 | — |
| La Pelota (rara) | Rebota 2 veces | 10 / 0.6 s | 17 | 25 | **Pessi**: +60%, más rápido, puntería perfecta |
| Vuvuzela | Cono 7 m, frena | 2 / 0.3 s | 7 | ∞ | **Neymal**: doble daño y alcance |
| Palo de Selfie | Cuerpo a cuerpo, 2.8 m | 8 / 0.55 s | 15 | 50 | — |

Consumibles (se agarran al pasar): **Mate** (+25), **Empanada** (+15),
**Vacuna** (cura efectos negativos y da -10% de daño recibido por 20 s).

**Skins de armas** (cosméticas, se eligen en el lobby): Clásica, Camuflaje,
Oro, Diamante y Plasma (animada). Cada una tiene las funas necesarias para
desbloquearla (`required_kills`), listas para cuando haya base de datos y maestría.

## Eventos globales

La probabilidad se tira una vez al empezar la partida, según quién juega.

| Evento | Probabilidad | Efecto |
|---|---|---|
| Ataque Nuclear | 0 / 25 / 50 / 80 / 90% con 0–4+ potencias nucleares | Aviso de 10 s; 60 de daño a todos (6 dentro de un búnker) |
| COVID | 40% si hay alguien de riesgo | 2/s por 20 s y lentitud a los de riesgo |
| Muerte por edad | 15% por personaje con la tag | Muere de golpe, sin aviso |
| Apagón | 30% | 35 s de noche; cada personaje lleva una linterna |
| Hiperinflación | 20% por argentino | La zona se achica ya y al doble de velocidad |
| Lluvia de Empanadas | 35% | Caen 14 empanadas dentro de la zona |

## Rivalidades y sinergias

Se activan a menos de 12 m: los dos dicen su frase y cambia el daño entre ellos.

| Relación | Personajes | Daño entre ellos |
|---|---|---|
| La Grieta | Pilei vs Birchner | +25% |
| Revancha Electoral | Tromp vs Bidet | +25% |
| El Muro | Tromp vs AMLOL | +25% |
| Invierno Ruso | Pupin vs Napoleón | +25% |
| Guerra Comercial | Tromp vs Xi | +20% |
| Bromance Nuclear | Tromp y Kim | -25% |
| Colusión | Pupin y Tromp | -20% |
| Dupla del PSG | Neymal y Pessi | -20% |
| Club de la Tercera Edad | Mirta y Bidet | -20% |
| Funding Secured | Elon y Smoke Dogg | -20% |
| Pacifistas Armados | Zweistein y Gandy | -20% |

## Cómo agregar contenido (sin tocar código)

- **Personaje**: crear `characters/roster/<id>.tres` (copiar uno existente), su cara en
  `characters/faces/<id>.svg` y sumarlo a `characters/roster.tres`.
- **Arma**: crear `weapons/data/<id>.tres`. Aparece sola en el loot según `spawn_weight`.
  Para que sea arma firma, completar `signature_character` con el id del personaje.
- **Efecto de estado**: crear `combat/statuses/<id>.tres`.
- **Habilidad**: crear `abilities/data/<id>.tres` usando uno de los 7 tipos
  (dash, área, buff propio, proyectil, súper salto, muro, piscinazo).
- **Rivalidad**: sumar una entrada en `combat/rivalries.tres`.
- **Evento**: crear su `.tres` en `events/` y sumarlo a `event_pool` en `autoload/game_manager.gd`.

## Arquitectura en red (resumen)

- El host es servidor y jugador (peer 1). Hasta 9 más se conectan por IP (ENet, puerto 7777).
- **El servidor decide** vida, efectos, golpes, armas, loot, eventos, zona y bots.
- **Cada jugador mueve su personaje** (respuesta inmediata); el servidor le manda empujones y dashes.
- Los proyectiles se simulan igual en todos; solo el servidor detecta impactos.
- La isla se genera con una semilla fija: todos la generan idéntica sin mandarla por red.

## Pendientes conocidos

- Jugar por internet: el host debe abrir el puerto 7777 UDP o usar una VPN de juegos (o integrar Steam).
- El "ragdoll" es un cuerpo que sale volando entero; falta un ragdoll con huesos.
- La música temática y el mapa mundial de selección todavía no están.
- Maestría, ranking y pase de batalla necesitan una base de datos (servidor propio o servicio).

## Créditos

- Personajes base: **Mini Characters** de Kenney (www.kenney.nl), licencia CC0.
  Ver `assets/kenney_mini_characters/License.txt`.
- Todo lo demás (código, caras, mapa, sonidos sintetizados, armas) es del proyecto.
