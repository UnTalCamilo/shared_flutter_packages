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
| `face_detection` | `[EXISTE]` | Detección **geométrica** de rostro (bounding box, landmarks, ángulos) sobre `camera_core`; ML Kit confinado; `IFaceDetector.detect(CameraFrame)` + `FaceDetection.create()`; config mínima; sin estado de stream (throttle/UI en la app). | CAPPFRONT (consumiéndolo); SAPIENS (guía facial futura) | Extraído y verificado (2026-10-01). Solo detección geométrica; sin reconocimiento ni verificación de identidad. |
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

`[EXISTE]` **`face_detection`** — segunda capacidad de visión; extraída de CAPPFRONT (2026-10-01). Encapsula `google_mlkit_face_detection ^0.15.1` tras `IFaceDetector` (`detect(CameraFrame) → FaceDetectionResult?` + `dispose()`), `FaceDetection.create()`, modelos propios (`DetectedFace`/`FaceLandmarkKey`/`FaceDetectionResult`, con landmarks y ángulos de Euler), `FaceDetectionConfig` mínima (`maxFaces`/`enableLandmarks`/`minFaceSize`/`performanceMode`) y puerto `FaceDetectionLogger`. No expone tipos de ML Kit ni `package:camera`. Preview-only: sin estado de stream; throttle/drop-if-busy y UI (overlay/brackets/mapeo de coordenadas) permanecen en la app. **Solo detección geométrica**; sin reconocimiento ni verificación de identidad. Validación: `flutter analyze` limpio + 26/26 tests del paquete; CAPPFRONT lo consume por `path:` (`flutter analyze` 0 errores, 33/33 tests de cámara). La conversión `CameraFrame→InputImage` se duplica de forma controlada respecto a `qr_scanner` (decisión R1/D3).

Hallazgos previos en CAPPFRONT (auditoría de código real):
- `package:camera` **sin imports directos** en `lib/` tras encapsularse en `camera_core`.
- Procesamiento de archivos de imagen **mínimo**: selección + carga multipart del original; **no** hay pipeline de compresión, resize, crop, formato ni EXIF.
- El único "procesamiento de imagen" presente es un **shader GPU del preview en vivo**, no una transformación de archivos.
- Existe un **QR legacy** separado basado en `mobile_scanner` que duplica una capacidad que `qr_scanner` ya cubre. **No migrado.**
- **Detección facial** — **extraída** al paquete `face_detection` (2026-10-01). Tras la extracción, CAPPFRONT ya **no** importa `google_mlkit_*` en `lib/`; ML Kit queda confinado en los paquetes de capacidad (`face_detection`, `qr_scanner`). El overlay facial, el estilo de brackets y el mapeo de coordenadas `mapFrameToView`/`mapRectToView` permanecen en CAPPFRONT (decisión R2).
- Servicios de almacenamiento, logger de app y módulos de pegamento (DI) **no** son por sí mismos paquetes compartidos.
- No hay evidencia para crear por anticipado `photo_capture`, `image_processing`, `camera_filters` ni `document_scanner`.

---

## 13. Decisiones pendientes de aprobación del usuario

Estas **no** están decididas; se registran para acordarlas antes de implementar:

- **D1 — Orden del roadmap:** ¿se arranca por consolidar el QR legacy de CAPPFRONT (§10, paso 1)?
- **D2 — Frontera de UI de `face_detection`:** ✅ **RESUELTA (2026-10-01).** El paquete **no** incluye overlay; solo expone datos geométricos. El overlay, los brackets y el mapeo `mapFrameToView`/`mapRectToView` permanecen en CAPPFRONT. (`camera_core` no se modificó.)
- **D3 — Conversión `CameraFrame→InputImage`:** ✅ **RESUELTA parcialmente (2026-10-01).** Se adoptó **duplicación controlada** entre `qr_scanner` y `face_detection` (son 2 adaptadores ML Kit). El umbral para evaluar un `mlkit_frame_adapter` mínimo sigue siendo el 3.er adaptador. No se creó `vision_core`.
- **D4 — Alcance del catálogo:** ¿se confirma que `document_*`, `image_processing`, `image_quality` y `camera_filters` quedan `[FUTURO]`/`[NO JUSTIFICADO HOY]` sin diseño detallado hasta tener caso real?
- **D5 — SAPIENS primero QR:** ¿la integración de SAPIENS empieza por QR antes que por documentos?
- **D6 — Reconocimiento/verificación de identidad:** ¿se trata como capacidad separada futura con decisión de privacidad explícita, fuera de `face_detection`?
- **D7 — Repositorio:** ¿se mantiene el monorepo simple con `path:` sin herramientas de workspace por ahora?
- **D8 — Motor documental/OCR:** ¿el motor (ML Kit vs nativo vs remoto) se decide con el caso real, no ahora?

La decisión vigente es de **alcance y arquitectura**. No hay autorización implícita para migrar QR, modificar apps, cambiar `pubspec.yaml` ni implementar nuevos paquetes.

---

## 15. Evaluación de aplicabilidad en CAPPFRONT

> Auditoría de **código real** de `D:\Projects\cappfront`, guiada por este documento. No modifica código, `pubspec.yaml`, paquetes ni apps. Clasifica responsabilidades, no carpetas. Las clasificaciones son evaluaciones, **no decisiones aprobadas**.

**1. Fecha de revisión:** 2026-10-01.

**2. Estado observado de CAPPFRONT:**
- `camera_core` y `qr_scanner` consumidos vía dependencias `path:`. `package:camera` **sin imports directos** en `lib/` (encapsulado en `camera_core`).
- ML Kit (`google_mlkit_*`) aparece en **un único archivo**: `core/services/camera/face_detection_service.dart`.
- `mobile_scanner` aparece en **un único archivo**: `features/shared/qr/view/pages/qr_scan_screen.dart` (QR legacy, no migrado).
- `package:qr_scanner` solo se usa en `features/qr_demo/qr_scanner_demo_screen.dart` (pantalla demo de integración).
- Shader de preview: solo `core/services/realtime/color_adjust_shader.dart` + `realtime_preview_view.dart`, con `RealtimeParams`/`CameraLooks`.
- **No existe pipeline de procesamiento de archivos de imagen:** sin compresión, resize, crop, corrección de perspectiva, conversión de formato ni EXIF en todo `lib/`.

**3. Tabla de responsabilidades y clasificación:**

| Responsabilidad | Archivos representativos | Evidencia de uso real | Clasificación | Justificación | Destino (si aplica) | Dependencias / riesgos |
|---|---|---|---|---|---|---|
| Infraestructura de cámara (preview, controles, captura, frames, permisos) | consumida vía `camera_core`; `core/di/camera_module.dart`, `core/services/camera/app_logger_camera_logger.dart` | Toda la experiencia de cámara la usa | `[EXISTE] COMPARTIR` (ya hecho) | Ya extraída y validada | `camera_core` | Ninguno nuevo |
| Experiencia fotográfica (pantalla, controles de producto, hoja de resultado, composición) | `features/camera/presentation/camera_experience_screen.dart`, `camera_controls_bar.dart`, `camera_preview_area.dart`, `capture_result_sheet.dart`, `composition_overlay/guide.dart` | Pantalla de cámara de CAPPFRONT | `CONSERVAR EN APP` | UX/producto; orquesta lifecycle, looks, guardado | — | Acopla `camera_core` + shader + face + storage |
| Detección facial (motor geométrico) | `core/services/camera/face_detection_service.dart`, `core/models/camera/face_detection_result.dart` | Alimentada por `frameStream` en la pantalla de cámara (preview-only) | `COMPARTIR PARCIALMENTE` → el motor y modelos; `[PROPUESTO] face_detection` | ML Kit confinado, modelos propios, patrón idéntico a `qr_scanner` | `face_detection` (propuesto) | Alinear ML Kit `commons ^0.13.0`; duplicación `CameraFrame→InputImage`; rotación/landscape sin calibrar |
| Overlay facial (mapeo frame→vista + pintura) | `features/camera/presentation/widgets/face_detection_overlay.dart` | Overlay del preview | `COMPARTIR PARCIALMENTE` | `mapFrameToView`/`mapRectToView` (cover/crop/mirror) es genérico y reutilizable; el *estilo* de brackets es de producto | mapeo → candidato a `face_detection`; estilo → app | El mapeo depende del `BoxFit.cover` de `camera_core.buildPreview`; frontera a decidir (D2) |
| Filtros / shader de preview | `core/services/realtime/color_adjust_shader.dart`, `realtime_preview_view.dart`, `core/models/camera/realtime_params.dart` | Looks en la pantalla de cámara | `CONSERVAR EN APP` (`[NO JUSTIFICADO HOY]` como paquete) | Un solo shader, 3 uniforms (brightness/contrast/saturation), catálogo de "looks" de producto; procesa el **render**, no archivos | — | Reevaluar solo si ≥2 efectos reales + API de parámetros estable |
| QR (motor) | consumido vía `qr_scanner`; `features/qr_demo/qr_scanner_demo_screen.dart` | Demo de integración | `[EXISTE] COMPARTIR` (ya hecho) | Ya extraído | `qr_scanner` | — |
| QR legacy (captura + overlay propios) | `features/shared/qr/view/pages/qr_scan_screen.dart` | **En uso real** para el flujo de QR del cliente | `COMPARTIR PARCIALMENTE` → reemplazar su captura `mobile_scanner` por `camera_core`+`qr_scanner`; UI/negocio se quedan | Duplica una capacidad ya cubierta; `mobile_scanner` directo | motor → `qr_scanner`; UI → app | Paridad de UX de escaneo (recuadro, torch); **no migrar sin aprobación** |
| QR negocio (payload, roles, expiración) | `features/shared/qr/models/qr_payload.dart`, `viewmodel/qr_scan_vm.dart` | Procesa el QR escaneado | `CONSERVAR EN APP` | Lógica de negocio institucional | — | — |
| QR generación | `features/shared/qr/view/pages/qr_generate_screen.dart` | Genera QR del fotógrafo | `CONSERVAR EN APP` | Negocio + `qr_flutter` | — | — |
| Guardado en galería | `core/services/storage/media_storage_service_impl.dart` (+ contrato + `storage_result.dart`) | `camera_experience_screen`, `booking_user_vm` | `REVISAR MÁS ADELANTE` | Adaptador fino de un plugin; reutilizable en concepto pero hoy delgado y específico | posible `media_storage` futuro | Depende de `CaptureResult` (`camera_core`) |
| Subida/entrega de imágenes (fotógrafo) | `features/photographers/sessions/viewmodel/session_photographer_vm.dart`, `core/data/photographer/remote_photographer_ds.dart` | Flujo de entrega | `CONSERVAR EN APP` | Negocio; subida multipart cruda, sin procesamiento | — | — |
| Selección de imágenes (perfil/chat/registro) | `features/shared/edit_profile/viewmodel/*`, `features/auth/viewmodel/register_vm.dart`, `chat_screen.dart` | `image_picker` | `CONSERVAR EN APP` | Flujos de negocio; sin procesamiento | — | — |
| Procesamiento de imágenes (compresión/crop/perspectiva/resize/EXIF) | — | **No existe** en el código | n/a | No hay implementación que extraer | — | No inventar |

**4. Candidatos reales de extracción (no aprobados):**
- `[PROPUESTO] face_detection` — es el único candidato con base de código suficiente: motor ML Kit confinado + modelos propios + mapeo de overlay genérico. Requiere decidir la frontera de UI (D2) y la estrategia `CameraFrame→InputImage` (D3).
- `COMPARTIR PARCIALMENTE` del QR legacy — no es un paquete nuevo: es **reemplazar** la captura `mobile_scanner` de `qr_scan_screen.dart` por `camera_core`+`qr_scanner`, dejando UI y negocio en la app (roadmap §10, paso 1).

**5. Debe permanecer en CAPPFRONT:**
- Toda la experiencia fotográfica (`features/camera/presentation/*`), el shader y sus looks (`realtime/*`, `RealtimeParams`), el negocio y UI de QR (`features/shared/qr/*`), la subida/entrega del fotógrafo, la selección de imágenes y la visualización de galerías. El guardado en galería queda `REVISAR MÁS ADELANTE`.

**6. Hallazgos que precisan el snapshot técnico (§12):**
- Confirmado que la detección facial se alimenta del `frameStream` de `camera_core` en la pantalla de cámara (preview-only; drop-if-busy en la pantalla). El servicio y modelos ya son neutrales → traslado de bajo riesgo técnico.
- El overlay facial contiene **lógica genérica reutilizable** (`mapFrameToView`/`mapRectToView`, cover/crop/mirror) acoplada al `BoxFit.cover` de `camera_core.buildPreview`: es un matiz nuevo para la frontera de UI de `face_detection` (D2).
- Reconfirmado: **sin procesamiento de archivos de imagen** en todo `lib/` (ni compresión, ni resize, ni crop, ni perspectiva, ni EXIF). `image_processing` sigue siendo `[FUTURO]` sin base de código.

**7. Próximos pasos sugeridos (no aprobados):**
- Mantener el orden del roadmap (§10): primero consolidar el QR legacy sobre `qr_scanner`+`camera_core`; después definir/extraer `face_detection`.
- Antes de `face_detection`, cerrar D2 (frontera del overlay) y D3 (conversión de frames).
- Ninguno de estos pasos está autorizado por esta auditoría; requieren aprobación explícita (D1–D8).

---

## 16. Pregunta guía para retomar

¿Podemos ofrecer a CAPPFRONT fotografía y a SAPIENS captura institucional de identidad **reutilizando capacidades técnicas comunes**, sin que ninguna app tenga que adoptar la UI, los controles ni el flujo de la otra?

Al retomar: revisar primero este contexto y la propuesta arquitectónica más reciente. No convertirlo automáticamente en una lista de tareas; primero acordar alcance y fronteras de responsabilidad (D1–D8).
