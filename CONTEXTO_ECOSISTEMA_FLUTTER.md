# Contexto del ecosistema Flutter compartido

> **Documento rector y de continuidad.** Es la guía principal y persistente del ecosistema de paquetes Flutter compartidos. No es una lista de tareas ni una autorización de implementación. Su propósito es (a) conservar la visión arquitectónica para CAPPFRONT, SAPIENS_ACADEMIC y futuras apps, y (b) permitir retomar cualquier sesión de Kiro sin reconstruir el historial.
>
> **Cómo leer la madurez:** a lo largo del documento se etiqueta cada elemento como:
> - `[EXISTE]` — implementado y verificado en el código actual.
> - `[PROPUESTO]` — recomendado, con base de código cercana; **requiere aprobación** antes de implementar.
> - `[FUTURO]` — visión sin código ni caso de uso concreto todavía; no se diseña en detalle ni se compromete.
> - `[NO JUSTIFICADO HOY]` — se evaluó y se decidió no extraer por ahora.
>
> Nada etiquetado `[PROPUESTO]` o `[FUTURO]` está aprobado para implementación por el hecho de aparecer aquí.

---

## 1. Propósito y visión

Se está construyendo una **base compartida de capacidades de cámara, captura y visión** para aplicaciones Flutter con objetivos y experiencias distintas. Hoy son dos:

- **CAPPFRONT** — aplicación orientada principalmente a fotografía: captura mediante cámara, controles de cámara y exposición, filtros/procesamiento visual en tiempo real mediante shaders, y detección facial con ML Kit. Es la **referencia técnica** para extraer y validar capacidades reutilizables a partir de código real.
- **SAPIENS_ACADEMIC** — aplicación universitaria: hoy necesita escaneo QR para ingreso/asistencia; ha tenido dificultades de configuración y compatibilidad multiplataforma, en particular en el contexto **Huawei/HMS**. A futuro deberá incorporar captura y procesamiento de documentos de identidad (cédula, carnet, pasaporte), y algunos flujos podrían requerir detección facial, OCR, extracción de información mediante IA y envío de solicitudes a dependencias universitarias.

**Problema que resuelve:** evitar que cada app reimplemente —con sus propios bugs de compatibilidad— la infraestructura de cámara y los motores de visión, reutilizando motores, contratos y resultados técnicos **sin** forzar que las apps compartan pantallas, controles, navegación ni reglas de negocio.

**Lo que NO es:** no es un framework que gobierne la UI o el flujo de ambas apps, ni una nueva marca/monorepo-producto. Es infraestructura + capacidades que las apps consumen a voluntad.

---

## 2. Principio rector

> **Capacidad técnica ≠ experiencia de usuario ≠ flujo de negocio.**

- Los **paquetes compartidos** ofrecen motores, contratos y **resultados técnicos tipados** (p. ej. "hay un código con este valor", "hay un rostro en estas coordenadas", "el documento está encuadrado y estable").
- La **experiencia de usuario** (guías visuales, marcos, siluetas, controles, pantallas, navegación, branding) la decide **cada aplicación**.
- El **flujo de negocio** (qué significa el dato, verificar identidad, persistir, enviar al backend, el trámite académico o la entrega fotográfica) vive **en la aplicación**.

Frontera operativa: **la capacidad termina donde empieza una decisión de producto o de negocio.** "Detecté un rostro con estos landmarks" es capacidad; "este es el estudiante X y autorizo el trámite" es negocio. Una capacidad nunca afirma identidad ni toma decisiones institucionales.

---

## 3. Arquitectura conceptual

Cuatro capas, con dependencia unidireccional (hacia abajo). `camera_core` nunca conoce una capacidad; las capacidades dependen de `camera_core`; las apps componen todo.

```text
┌───────────────────────────────────────────────────────────────┐
│ 4. APLICACIONES  (experiencia + negocio, NO compartidas)        │
│    CAPPFRONT (fotográfica)      SAPIENS_ACADEMIC (académica)     │
└───────────────┬───────────────────────────────┬────────────────┘
                │ consumen                       │ consumen
┌───────────────▼───────────────────────────────▼────────────────┐
│ 3. PRIMITIVAS VISUALES OPCIONALES  (UI técnica, neutral)         │
│    Viven DENTRO de su capacidad (p. ej. QrScannerOverlay).       │
│    No imponen Scaffold, AppBar, navegación ni diseño.            │
└───────────────┬─────────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────────┐
│ 2. CAPACIDADES INDEPENDIENTES  (datos técnicos, motor confinado)  │
│    qr_scanner · face_detection · document_capture · …            │
│    cada una: contrato + adaptador(ML Kit|nativo|remoto) + modelos │
└───────────────┬─────────────────────────────────────────────────┘
                │ dependen SOLO de ↓ (CameraFrame / imágenes)
┌───────────────▼─────────────────────────────────────────────────┐
│ 1. INFRAESTRUCTURA                                               │
│    camera_core (ICameraService, CameraFrame, preview, controles) │
└──────────────────────────────────────────────────────────────────┘
```

Responsabilidades por capa:
1. **Infraestructura de cámara (`camera_core`):** hardware, preview, controles (zoom/flash/exposición/enfoque), captura, frame stream, permisos, estado, ciclo de vida. Produce `CameraFrame` neutral. No conoce visión. **Único punto que toca `package:camera`.**
2. **Capacidades independientes:** reciben frames/imágenes, ejecutan un motor confinado y emiten resultados técnicos con modelos propios. Cada capacidad = contrato pequeño + adaptador(es) de motor + modelos + UI opcional.
3. **Primitivas visuales opcionales:** overlays/guías/marcos composables, **dentro** de su capacidad (no un paquete UI común que acople capacidades distintas). Siempre opcionales.
4. **Aplicaciones:** componen preview + capacidades + sus propios widgets; orquestan lifecycle y resuelven negocio.

**Regla anti-monolito:** no crear un `vision_core` que agrupe motores heterogéneos. Cada capacidad confina su propio motor.

---

## 4. Catálogo de capacidades y madurez

| Paquete / capacidad | Estado | Responsabilidad | Consumidor actual / potencial | Criterio para extraer / existir |
|---|---|---|---|---|
| `camera_core` | `[EXISTE]` | Infraestructura: cámara, preview, controles, captura, frame stream, permisos, estado. `CameraFrame` neutral. | CAPPFRONT (actual); SAPIENS (futuro) | Ya extraído y validado. |
| `qr_scanner` | `[EXISTE]` | Capacidad QR/barras sobre `camera_core`; ML Kit confinado; sesiones con throttle + política de duplicados; overlay opcional. | CAPPFRONT (demo); SAPIENS (futuro, ingreso) | Ya extraído. |
| `face_detection` | `[PROPUESTO]` | Detección **geométrica** de rostro (bounding box, landmarks, ángulos). | CAPPFRONT (ya tiene el servicio); SAPIENS (guía facial futura) | El servicio y modelos ya existen en CAPPFRONT y podrían trasladarse. Requiere aprobar frontera de UI y estrategia de conversión de frames. |
| `document_capture` | `[FUTURO]` | Detección de documento + evaluación de calidad + autocaptura (orquestación técnica). | SAPIENS (futuro) | Solo con caso real de SAPIENS. Agrupar las tres sub-funciones (comparten frame y ciclo de vida). |
| `document_recognition` | `[FUTURO]` | OCR y extracción estructurada de campos, con confianza. | SAPIENS (futuro) | Solo con caso real. El **esquema de campos por tipo de documento** es parcialmente negocio. |
| `image_processing` | `[FUTURO]` | Recorte, corrección de perspectiva, resize, conversión de formato. | SAPIENS (futuro, documental) | Solo cuando `document_capture` deba entregar un documento rectificado a OCR. **Hoy no existe nada de esto en CAPPFRONT.** |
| `image_quality` | `[FUTURO / probablemente NO paquete]` | Nitidez, luz, desenfoque, estabilidad. | — | Vive dentro de `document_capture` salvo que aparezca un segundo consumidor claro. |
| `camera_filters` (shaders) | `[NO JUSTIFICADO HOY]` | Filtros/ajustes de preview por shader. | CAPPFRONT | Permanece en CAPPFRONT: un solo efecto, pocos uniforms, catálogo de "looks" de producto. Reevaluar si surgen ≥2 efectos reales y una API de parámetros estable. |
| `photo_capture` | `[NO JUSTIFICADO HOY]` | — | — | `camera_core` ya cubre control + captura + resultado + frames. Crearlo sería renombrar responsabilidades existentes. |
| Reconocimiento / verificación de identidad | `[FUTURO, capacidad separada]` | Comparación/identificación biométrica. | SAPIENS (hipotético) | Capacidad distinta de `face_detection`, de mayor riesgo; requiere decisión explícita de privacidad y seguridad. No forma parte de `face_detection`. |

---

## 5. Visión documental e identificación (preservada, sin comprometer)

Visión futura para SAPIENS (trámites de identidad: cédula, carnet, pasaporte). Se conserva como **dirección**, no como diseño aprobado:

1. La app inicia un trámite (p. ej. actualización de datos) y solicita capturar rostro y/o documento.
2. La **app** presenta su guía visual propia (marco, esquinas, silueta, instrucciones).
3. Una capacidad técnica puede **detectar el documento**, **evaluar calidad** (nitidez/luz/encuadre/estabilidad) y determinar cuándo **capturar automáticamente**.
4. Otra capacidad puede **corregir perspectiva**, **recortar** y ejecutar **OCR/extracción** de campos.
5. La app presenta los datos extraídos para **revisión y confirmación humana**.
6. La **app** gestiona formulario, navegación, solicitud y envío a la dependencia.

CAPPFRONT podría reutilizar motores técnicos similares con su propia experiencia fotográfica.

**Distinciones que no deben colapsarse en sinónimos:**
- **Detección facial** — localizar que hay un rostro y dónde (geometría/landmarks). No afirma identidad.
- **Análisis de geometría facial** — ángulos, apertura, orientación; sigue siendo técnico.
- **Reconocimiento / identificación biométrica** — determinar *quién* es. Capacidad separada, mayor riesgo.
- **Verificación de identidad** — decisión de negocio/seguridad; **nunca** es consecuencia automática de detectar un rostro o de un OCR.

Estas cuatro cosas **no comparten paquete** por defecto y no se asumen equivalentes.

---

## 6. IA y motores

- Cada capacidad define un **contrato propio pequeño** y **confina su motor** (ML Kit, API nativa como VisionKit, o servicio remoto) tras un **adaptador** interno. Ni `InputImage`, `Barcode`, `Face`, ni tipos de proveedor cruzan la API pública.
- **No** crear una abstracción universal de IA (`vision_core`) ni una interfaz que intente representar todos los motores. Los adaptadores son específicos por capacidad.
- Un motor se intercambia cambiando el **adaptador**, no el contrato de la capacidad. Ejemplo (futuro): `document_recognition` con adaptadores ML Kit / nativo / remoto.
- **Conversión `CameraFrame → InputImage`:** hoy aparece duplicada (en `qr_scanner` y en el servicio facial de CAPPFRONT), ~120 líneas estables. Regla acordada: **duplicación controlada** mientras haya ≤2 adaptadores ML Kit; evaluar un paquete **mínimo** `mlkit_frame_adapter` (solo la conversión) al llegar al tercero. Ese adaptador, si existe, **nunca** lo toca `camera_core` ni una capacidad que no use ML Kit. (El umbral exacto es decisión pendiente — ver §13, D3.)

---

## 7. UI y composición

- Los paquetes pueden ofrecer **componentes visuales técnicos y composables** (overlays, guías, marcos, indicadores), siempre **opcionales**.
- Un paquete **no debe** imponer: Scaffold, AppBar, navegación, botones institucionales, formularios, pantallas completas ni diseño de marca.
- Composición esperada (la app decide el arreglo):
  ```text
  Stack[ CameraPreview, QrScannerOverlay, controles-de-la-app ]
  Stack[ CameraPreview, FaceGuideOverlay, (datos de face_detection → la app pinta/decide), captura ]
  Stack[ CameraPreview, DocumentFrameOverlay, QualityFeedback, autocaptura ]
  ```
- Se permiten **experiencias de conveniencia** (widgets llave-en-mano) por encima de los primitivos, pero **nunca como única API**: deben ser opcionales y no imponer navegación. Patrón de referencia ya existente: `CameraView` compone preview + controles por defecto sin obligar a usarlo.

---

## 8. Privacidad y manejo de datos

Responsabilidades técnicas (no políticas institucionales). Aplican con fuerza al manejar rostros y documentos de identidad:

- **Minimización:** las capacidades devuelven lo mínimo técnico (coordenadas, confianza, texto); no retienen frames ni imágenes más allá del procesamiento.
- **Sin datos sensibles en logs:** no registrar imágenes, bytes, valores de documentos ni landmarks. Los puertos de logging (`CameraLogger` y equivalentes) solo registran eventos técnicos. *Punto a revisar al pasar de QR a documentos: evitar que `toString()` de los modelos exponga valores sensibles.*
- **Procesamiento local por defecto:** on-device salvo que la **app** active explícitamente un motor remoto. Ningún adaptador remoto es el camino por defecto.
- **Separación resultado técnico ↔ decisión de negocio:** "rostro detectado" ≠ "identidad verificada"; "texto extraído" ≠ "trámite aprobado".
- **Revisión humana cuando corresponda:** los datos extraídos (OCR/campos) se presentan para confirmación del usuario antes de cualquier acción institucional.
- **Ciclo de vida:** liberar detectores (`dispose`), detener frame streams en background, no persistir resultados dentro de la capacidad.
- **Puntos de decisión de la app:** activar motor remoto; persistir/enviar al backend; nivel de logging; retención de capturas.

---

## 9. Organización del repositorio

- **Un solo repositorio Git** en `D:\shared_flutter_packages\` con **paquetes independientes**, cada uno con sus contratos, implementación, pruebas, ejemplo y documentación (`CHANGELOG`/`README`).
- Desarrollo local mediante dependencias `path:`; refactor y pruebas cruzadas atómicas; fronteras explícitas (los imports fallan si se cruza de capa).
- Versionado por paquete vía `CHANGELOG`; sin herramientas de monorepo (melos/workspaces) por ahora — no se justifican a esta escala.
- Cada paquete es autónomo: extraerlo a un repo propio o publicarlo en un pub privado en el futuro es mecánico y no bloquea nada hoy.
- No dividir repositorios sin una razón operativa clara.

---

## 10. Evolución y roadmap (secuencia propuesta, no obligatoria ni aprobada)

El ecosistema **crece por caso de uso real**, no por diagrama. Secuencia sugerida, priorizada por valor y riesgo; cada paso deja ambas apps funcionando:

1. **Consolidar el QR legacy de CAPPFRONT** sobre `qr_scanner` + `camera_core` (hoy `qr_scan_screen.dart` usa `mobile_scanner` directo). Elimina duplicación real; el negocio no se toca. `[PROPUESTO como siguiente paso]`
2. **Definir y extraer `face_detection`** (servicio y modelos ya existentes en CAPPFRONT) con overlay opcional. `[PROPUESTO]`
3. **Integrar SAPIENS como consumidor de QR**, con UI propia; incluye la **verificación Huawei/HMS pendiente**. `[FUTURO cercano]`
4. **Definir la frontera de captura documental** (`document_capture`) con un caso real de SAPIENS — solo diseño. `[FUTURO]`
5. **Capacidades documentales + OCR** (`document_capture` → `image_processing` → `document_recognition`), en ese orden de dependencia, solo cuando el trámite real lo exija. `[FUTURO]`

No entran al roadmap por ausencia de caso real: `camera_filters`, `image_quality` como paquete, `photo_capture`, reconocimiento/verificación biométrica.

Este documento debe usarse para **evaluar nuevas solicitudes** antes de crear paquetes o abstraer código: si un elemento es `[FUTURO]` o `[NO JUSTIFICADO HOY]`, primero se busca el caso real y se obtiene aprobación.

---

## 11. Reglas operativas para futuras sesiones de Kiro

Al retomar o proponer cambios en este ecosistema:

1. **Leer este documento primero**, junto con cualquier propuesta arquitectónica reciente, antes de proponer cambios o crear paquetes.
2. **No asumir que lo `[FUTURO]`/`[PROPUESTO]` está aprobado.** Aparecer aquí no autoriza implementación.
3. **Auditar el código real** de la app/paquete antes de proponer una extracción; no inferir capacidades por nombres de carpeta.
4. **No trasladar UI ni lógica de negocio** a paquetes compartidos sin justificación explícita. Las capacidades entregan datos técnicos; las apps deciden presentación y negocio.
5. **No modificar aplicaciones consumidoras** (CAPPFRONT, SAPIENS) ni sus `pubspec.yaml` sin autorización explícita del usuario.
6. **No modificar `camera_core` ni `qr_scanner`** salvo incompatibilidad real e imprescindible, y comunicándolo.
7. **No re-validar hardware** de cámara como rutina; la validación física ya la realizó el usuario.
8. **Actualizar este documento solo cuando una decisión arquitectónica haya sido APROBADA** por el usuario — no cuando únicamente se haya sugerido. Mover el elemento de `[PROPUESTO]`/`[FUTURO]` a `[EXISTE]`/principio acordado al implementarse o aprobarse.
9. **Preferir el caso real** sobre la especulación: ante la duda de crear un paquete, mantenerlo como `[FUTURO]` hasta que exista implementación o un caso concreto.

---

## 12. Estado técnico conocido (snapshot)

Rutas conocidas (actualizar solo las rutas si se trabaja desde otro equipo; los límites arquitectónicos no cambian):
- **Paquetes compartidos:** `D:\shared_flutter_packages\`
- **App de referencia técnica:** `D:\Projects\cappfront`
- **App consumidora futura:** `D:\SAPIENS\APPS\SAPIENS_ACADEMIC\`

`[EXISTE]` **`camera_core`** — infraestructura de cámara, API neutral y composable, `CameraFrame`, preview y controles. No filtra tipos de `package:camera`. Validación física realizada por el usuario (funciona). Última validación reportada: 44/44 tests, `flutter analyze` limpio. **No** re-proponer prueba de hardware como rutina. *Pendiente de verificar:* comportamiento en Huawei/HMS (sin Google Play Services), relevante para SAPIENS.

`[EXISTE]` **`qr_scanner`** — primer consumidor de `camera_core`; encapsula ML Kit tras contratos propios (`IQrScanner`, sesión, modelos neutrales); throttle + política de duplicados; overlay opcional. No expone tipos de ML Kit ni `package:camera`. Última validación reportada: 24/24 tests, análisis limpio. Alineado con la versión de ML Kit que usa CAPPFRONT (`google_mlkit_commons ^0.13.0`). Se creó una pantalla demo en CAPPFRONT con dos composiciones (preview + overlay) — es prueba de integración, **no** indica que QR sea central en CAPPFRONT.

Hallazgos previos en CAPPFRONT (auditoría de código real):
- `package:camera` **sin imports directos** en `lib/` tras encapsularse en `camera_core`.
- Procesamiento de archivos de imagen **mínimo**: selección + carga multipart del original; **no** hay pipeline de compresión, resize, crop, formato ni EXIF.
- El único "procesamiento de imagen" presente es un **shader GPU del preview en vivo**, no una transformación de archivos.
- Existe un **QR legacy** separado basado en `mobile_scanner` que duplica una capacidad que `qr_scanner` ya cubre. **No migrado.**
- **Detección facial** aislada detrás de un único punto de uso (ML Kit confinado) — candidata a extracción.
- Servicios de almacenamiento, logger de app y módulos de pegamento (DI) **no** son por sí mismos paquetes compartidos.
- No hay evidencia para crear por anticipado `photo_capture`, `image_processing`, `camera_filters` ni `document_scanner`.

---

## 13. Decisiones pendientes de aprobación del usuario

Estas **no** están decididas; se registran para acordarlas antes de implementar:

- **D1 — Orden del roadmap:** ¿se arranca por consolidar el QR legacy de CAPPFRONT (§10, paso 1)?
- **D2 — Frontera de UI de `face_detection`:** ¿el paquete incluye un overlay de guía facial componible, o solo expone datos y cada app pinta su guía?
- **D3 — Conversión `CameraFrame→InputImage`:** ¿duplicación controlada o `mlkit_frame_adapter` mínimo, y en qué umbral? (No `vision_core`.)
- **D4 — Alcance del catálogo:** ¿se confirma que `document_*`, `image_processing`, `image_quality` y `camera_filters` quedan `[FUTURO]`/`[NO JUSTIFICADO HOY]` sin diseño detallado hasta tener caso real?
- **D5 — SAPIENS primero QR:** ¿la integración de SAPIENS empieza por QR antes que por documentos?
- **D6 — Reconocimiento/verificación de identidad:** ¿se trata como capacidad separada futura con decisión de privacidad explícita, fuera de `face_detection`?
- **D7 — Repositorio:** ¿se mantiene el monorepo simple con `path:` sin herramientas de workspace por ahora?
- **D8 — Motor documental/OCR:** ¿el motor (ML Kit vs nativo vs remoto) se decide con el caso real, no ahora?

La decisión vigente es de **alcance y arquitectura**. No hay autorización implícita para migrar QR, modificar apps, cambiar `pubspec.yaml` ni implementar nuevos paquetes.

---

## 14. Pregunta guía para retomar

¿Podemos ofrecer a CAPPFRONT fotografía y a SAPIENS captura institucional de identidad **reutilizando capacidades técnicas comunes**, sin que ninguna app tenga que adoptar la UI, los controles ni el flujo de la otra?

Al retomar: revisar primero este contexto y la propuesta arquitectónica más reciente. No convertirlo automáticamente en una lista de tareas; primero acordar alcance y fronteras de responsabilidad (D1–D8).
