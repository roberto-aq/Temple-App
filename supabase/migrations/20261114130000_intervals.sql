-- Intervalos: ejercicios por tiempo con trabajo, descanso y rondas
-- (isométricos, paseo del granjero, sprints…), aparte de los ejercicios y
-- series de la parte principal.
--
-- interval_protocols: las plantillas. interval_sessions: cada vez que se hizo
-- una, con copia del nombre y los tiempos para que el registro no cambie si
-- la plantilla se edita o se borra. Por eso protocol_id no es clave foránea.
--
-- Hay que aplicarla ANTES de instalar la versión de la app que trae
-- Intervalos: esa versión descarga estas tablas y, si no existen, no sincroniza.

create table public.interval_protocols (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  work_seconds integer not null check (work_seconds between 1 and 10800),
  rest_seconds integer not null check (rest_seconds between 0 and 10800),
  rounds integer not null check (rounds between 1 and 100),
  -- Cada ronda hace el lado izquierdo y luego el derecho.
  sided boolean not null default false,
  -- Pausa para cambiar de lado dentro de una ronda.
  switch_seconds integer not null default 10 check (switch_seconds between 0 and 600),
  -- Se anota el peso usado en cada sesión.
  weighted boolean not null default false,
  created_at timestamptz not null default now()
);

create index interval_protocols_user_id_idx on public.interval_protocols (user_id);

-- done: las rondas hechas, en orden: [{"side": "both" | "left" | "right", "s": 45}, …].
-- kg es null si la plantilla no lleva peso; unit es la unidad en que se anotó.
create table public.interval_sessions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  protocol_id uuid,
  day date not null,
  started_at timestamptz not null,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  work_seconds integer not null check (work_seconds between 1 and 10800),
  rest_seconds integer not null check (rest_seconds between 0 and 10800),
  rounds integer not null check (rounds between 1 and 100),
  sided boolean not null default false,
  kg numeric(5, 2) check (kg between 0 and 500),
  unit text not null default 'kg' check (unit in ('kg', 'lb')),
  done jsonb not null default '[]'::jsonb check (jsonb_typeof(done) = 'array'),
  notes text check (char_length(notes) <= 1000)
);

create index interval_sessions_user_id_day_idx on public.interval_sessions (user_id, day);

-- ---------------------------------------------------------------------------
-- Acceso: solo usuarios con sesión, y cada uno únicamente a sus filas
-- ---------------------------------------------------------------------------

revoke all on public.interval_protocols, public.interval_sessions from anon;
grant select, insert, update, delete on public.interval_protocols, public.interval_sessions to authenticated;

alter table public.interval_protocols enable row level security;
alter table public.interval_sessions enable row level security;

create policy "Ver mis plantillas de intervalos" on public.interval_protocols for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Crear mis plantillas de intervalos" on public.interval_protocols for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Editar mis plantillas de intervalos" on public.interval_protocols for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Borrar mis plantillas de intervalos" on public.interval_protocols for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Ver mis sesiones de intervalos" on public.interval_sessions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Crear mis sesiones de intervalos" on public.interval_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Editar mis sesiones de intervalos" on public.interval_sessions for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Borrar mis sesiones de intervalos" on public.interval_sessions for delete to authenticated
  using ((select auth.uid()) = user_id);
