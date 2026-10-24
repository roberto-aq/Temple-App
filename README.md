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
2. Aplica la migración: `supabase link --project-ref <ref>` y luego `supabase db push`.
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

## Ícono de la app

El yunque del tablero «Marca» del diseño. Las imágenes fuente (`assets/icon/`) se dibujan con código y luego se generan los íconos de cada plataforma:

```bash
flutter test tool/generate_icons.dart   # crea assets/icon/*.png
dart run flutter_launcher_icons         # Android (adaptativo y monocromo), iOS, web y Windows
```
