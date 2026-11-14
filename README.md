# Temple

App móvil (Flutter) para registrar entrenamientos de fuerza con **sobrecarga progresiva**: en cada ejercicio muestra lo que hiciste la última vez y cómo superarlo.

Diseño: proyecto «Temple» en Claude Design.

## Pantallas

| Pestaña / pantalla | Archivo |
|---|---|
| Hoy (sesión del día, semana, hoja «Cargar rutina») | `lib/screens/today_screen.dart` |
| Registrar ejercicio | `lib/screens/log_exercise_screen.dart` |
| Ejercicios / Elegir ejercicio | `lib/screens/library_screen.dart` |
| Crear ejercicio | `lib/screens/new_exercise_screen.dart` |
| Mis rutinas | `lib/screens/routines_screen.dart` |
| Crear / editar rutina | `lib/screens/routine_editor_screen.dart` |
| Progreso | `lib/screens/progress_screen.dart` |
| Progreso por ejercicio | `lib/screens/exercise_progress_screen.dart` |
| Historial | `lib/screens/history_screen.dart` |

## Estructura

- `lib/models/`: ejercicios, series, rutinas y plan del día.
- `lib/data/`: biblioteca base de ejercicios y copia local (`shared_preferences`).
- `lib/state/app_state.dart`: estado central (`ChangeNotifier`) expuesto con `AppScope`.
- `lib/sync/`: sincronización con Supabase (cola de cambios, conversión a filas, cliente).
- `lib/screens/auth_gate.dart`: elige entre iniciar sesión y la app; arma el estado de cada cuenta.
- `lib/logic/`: formato en español y reglas de progreso (1RM estimado, tendencias, sugerencias).
- `lib/widgets/`: componentes visuales e íconos del diseño.
- `supabase/migrations/`: tablas, permisos y políticas RLS.

## Supabase

Cada usuario entra con correo y contraseña y solo ve sus datos (RLS).

| Tabla | Contenido |
|---|---|
| `exercises` | Ejercicios creados por el usuario (la biblioteca base vive en la app) |
| `routines` | Rutinas; sus ejercicios en `items` (jsonb, en orden) |
| `day_plans` | Rutinas y ejercicios cargados cada día |
| `sets` | Una fila por serie |

Las 5 rutinas de inicio las crea un disparador al registrarse cada cuenta.

**Funciona sin conexión.** Cada cambio se aplica al instante en el teléfono y entra a una cola que se sube cuando hay red (al abrir la app, al volver a ella y con reintentos). Al descargar, lo del servidor se combina con lo que aún está en la cola. El estado se ve en el botón de cuenta (pestaña Hoy).

### Configurar

1. Copia `.env.example` como `.env` con la URL y la clave **pública** del proyecto (Project Settings → API). Nunca la clave secreta.
2. Aplica **todas** las migraciones de `supabase/migrations/`, en orden de nombre (empiezan por fecha y hora). De una de estas dos formas:
   - **Sin consola:** abre cada archivo, copia su contenido en el SQL Editor del proyecto y ejecútalo; luego el siguiente. Si uno falla, corrige el error antes de seguir: los siguientes dependen de él.
   - **Con la CLI:** `supabase link --project-ref <ref>` y luego `supabase db push`. Corre las que falten y anota cuáles ya aplicó.

   No mezcles las dos en el mismo proyecto: la CLI no sabe de las que corriste a mano e intentaría repetirlas. Si un proyecto empezó a mano y quieres pasar a la CLI, marca primero las ya aplicadas, sin ejecutarlas: `supabase migration repair --status applied <versión> …` (la versión es la fecha y hora del nombre del archivo).

   Cada cambio a la base va en un archivo nuevo de esta carpeta, aunque lo apliques a mano: así otro proyecto queda igual al correr todas.
3. En Authentication → Sign In / Providers, decide si exiges confirmar el correo. Con el correo integrado de Supabase se envían muy pocos por hora; para pruebas conviene desactivarlo.
4. Comprueba todo contra el proyecto real (registro, sincronización y que cada cuenta solo vea lo suyo):

   ```bash
   flutter test tool/supabase_smoke_test.dart --dart-define-from-file=.env --dart-define=SMOKE_EMAIL=tu@gmail.com
   ```

   Crea dos cuentas con alias de ese correo (`tu+temple-prueba-…@gmail.com`) y borra sus datos al terminar; las cuentas se eliminan a mano en Authentication → Users.

## Ejecutar

```bash
flutter pub get
flutter run --dart-define-from-file=.env            # en un teléfono o emulador Android
flutter run -d chrome --dart-define-from-file=.env  # en el navegador
flutter test
```

## Generar el APK

En el teléfono de pruebas no hace falta: conectado por USB, F5 en VS Code o `flutter run --dart-define-from-file=.env` instalan la app directamente. El APK es para el teléfono de uso diario, y se reparte por GitHub Releases (más abajo).

### Construir

1. **Sube la versión** en `pubspec.yaml`: `1.0.0+1` → `1.0.1+2`. El número tras el `+` es el que Android compara para saber que es más nueva: debe aumentar siempre, si no el teléfono no instala encima.
2. **Comprueba** que todo pasa y haz commit del cambio de versión:

   ```bash
   flutter analyze
   flutter test
   git commit -am "build: versión 1.0.1+2"
   ```

3. **Construye** con el `.env` (sin él, la app abre en «Falta configurar Supabase»):

   ```bash
   flutter build apk --release --dart-define-from-file=.env
   ```

4. **Revisa la salida del build**: si dice `android/key.properties no existe`, el APK quedó firmado con la clave de depuración y **no se instala encima** de la app del teléfono. No lo repartas; ver [Firma](#firma).

Queda en `build/app/outputs/flutter-apk/app-release.apk`. Se instala encima de la versión anterior, sin desinstalar y sin perder datos.

### Publicar en GitHub Releases

**Una sola vez:**

1. Crea en GitHub un repositorio **privado** llamado `temple`. Privado porque el APK lleva dentro la URL y la clave pública de Supabase (no es grave, RLS protege los datos, pero no hace falta repartirlas).
2. Conecta el proyecto y sube el código:

   ```bash
   git remote add origin https://github.com/<usuario>/temple.git
   git push -u origin main
   ```

3. Instala la CLI de GitHub e inicia sesión:

   ```bash
   winget install --id GitHub.cli
   gh auth login
   ```

**En cada versión** (después de [Construir](#construir); `1.0.1` es la versión de `pubspec.yaml` sin el `+`):

```bash
git tag v1.0.1
git push origin main v1.0.1
cp build/app/outputs/flutter-apk/app-release.apk build/temple-1.0.1.apk
gh release create v1.0.1 build/temple-1.0.1.apk --title "Temple 1.0.1" --notes "Qué cambió en esta versión"
```

**En el teléfono:**

1. Abre en el navegador `https://github.com/<usuario>/temple/releases/latest`, con tu cuenta de GitHub iniciada (el repositorio es privado). Conviene guardarla en favoritos o en la pantalla de inicio: siempre lleva a la última versión.
2. En *Assets*, toca `temple-1.0.1.apk` para descargarlo y ábrelo para instalar.
3. La primera vez, Android pide permitir «Instalar apps desconocidas» para el navegador.

### Firma

El release se firma con una clave propia, no con la de depuración:

- La clave: `C:\Users\User\.android-keys\temple-upload.jks` (fuera del proyecto).
- Su contraseña y ubicación: `android/key.properties` (fuera de git).

**Respalda los dos archivos** (por ejemplo en un USB o en tu nube personal, nunca en el repositorio). Sin ellos, los teléfonos que ya tienen la app no aceptan actualizaciones: habría que desinstalar e instalar de nuevo (los datos vuelven desde Supabase al entrar). Si `key.properties` no existe, el build avisa y firma con la clave de depuración.

## Ícono de la app

El yunque del tablero «Marca» del diseño. Las imágenes fuente (`assets/icon/`) se dibujan con código y luego se generan los íconos de cada plataforma:

```bash
flutter test tool/generate_icons.dart   # crea assets/icon/*.png
dart run flutter_launcher_icons         # Android (adaptativo y monocromo), iOS, web y Windows
```
