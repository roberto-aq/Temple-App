-- Temple: datos de cada usuario (ejercicios propios, rutinas, plan de cada día y series).
--
-- La biblioteca base de ejercicios vive en la app (lib/data/catalog.dart). Por eso
-- exercise_id es texto: puede ser un id de esa biblioteca («press-banca») o el uuid
-- de un ejercicio propio. Los ids los genera la app para poder crear sin conexión.

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

create table public.exercises (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  muscle_group text not null,
  kind text not null check (kind in ('weight', 'reps', 'seconds')),
  created_at timestamptz not null default now()
);

create index exercises_user_id_idx on public.exercises (user_id);

-- items: [{"ex": exercise_id, "sets": 3, "reps": 10}, …] en el orden de la rutina.
create table public.routines (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  items jsonb not null default '[]'::jsonb check (jsonb_typeof(items) = 'array'),
  created_at timestamptz not null default now()
);

create index routines_user_id_idx on public.routines (user_id);

-- Lo que se planeó entrenar un día: rutinas cargadas y ejercicios en orden.
create table public.day_plans (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null,
  routine_ids text[] not null default '{}',
  exercise_ids text[] not null default '{}',
  primary key (user_id, day)
);

-- Una fila por serie. reps son segundos en ejercicios de tiempo; kg es null si no lleva peso.
create table public.sets (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null,
  exercise_id text not null,
  reps integer not null check (reps between 1 and 300),
  kg numeric(5, 2) check (kg between 0 and 500),
  logged_at timestamptz not null default now()
);

create index sets_user_id_day_idx on public.sets (user_id, day);

-- ---------------------------------------------------------------------------
-- Acceso: solo usuarios con sesión, y cada uno únicamente a sus filas
-- ---------------------------------------------------------------------------

revoke all on public.exercises, public.routines, public.day_plans, public.sets from anon;
grant select, insert, update, delete on public.exercises, public.routines, public.day_plans, public.sets to authenticated;

alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.day_plans enable row level security;
alter table public.sets enable row level security;

create policy "Ver mis ejercicios" on public.exercises for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Crear mis ejercicios" on public.exercises for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Editar mis ejercicios" on public.exercises for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Borrar mis ejercicios" on public.exercises for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Ver mis rutinas" on public.routines for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Crear mis rutinas" on public.routines for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Editar mis rutinas" on public.routines for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Borrar mis rutinas" on public.routines for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Ver mis planes" on public.day_plans for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Crear mis planes" on public.day_plans for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Editar mis planes" on public.day_plans for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Borrar mis planes" on public.day_plans for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Ver mis series" on public.sets for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Crear mis series" on public.sets for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Editar mis series" on public.sets for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Borrar mis series" on public.sets for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Rutinas de inicio: cada cuenta nueva arranca con las 5 del diseño
-- (esquema privado, fuera de la API; nadie puede llamarla directamente)
-- ---------------------------------------------------------------------------

create schema if not exists private;

create function private.seed_starter_routines()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.routines (id, user_id, name, items, created_at) values
    (gen_random_uuid(), new.id, 'Pecho y tríceps',
      '[{"ex":"press-banca","sets":4,"reps":8},{"ex":"flexiones","sets":3,"reps":15},{"ex":"aperturas","sets":3,"reps":12},{"ex":"fondos","sets":3,"reps":10}]',
      now()),
    (gen_random_uuid(), new.id, 'Espalda y bíceps',
      '[{"ex":"dominadas","sets":4,"reps":8},{"ex":"remo-barra","sets":4,"reps":10},{"ex":"jalon","sets":3,"reps":12},{"ex":"curl","sets":3,"reps":12}]',
      now() + interval '1 millisecond'),
    (gen_random_uuid(), new.id, 'Piernas',
      '[{"ex":"sentadilla","sets":4,"reps":8},{"ex":"prensa","sets":4,"reps":12},{"ex":"zancadas","sets":3,"reps":10},{"ex":"pantorrillas","sets":4,"reps":15}]',
      now() + interval '2 milliseconds'),
    (gen_random_uuid(), new.id, 'Hombros',
      '[{"ex":"press-militar","sets":4,"reps":8},{"ex":"elevaciones-laterales","sets":3,"reps":15},{"ex":"pajaros","sets":3,"reps":15}]',
      now() + interval '3 milliseconds'),
    (gen_random_uuid(), new.id, 'Full body y core',
      '[{"ex":"peso-muerto","sets":4,"reps":6},{"ex":"plancha","sets":3,"reps":45},{"ex":"abdominales","sets":3,"reps":20}]',
      now() + interval '4 milliseconds');
  return new;
end;
$$;

revoke execute on function private.seed_starter_routines() from public, anon, authenticated;

create trigger on_auth_user_created_seed_routines
  after insert on auth.users
  for each row execute function private.seed_starter_routines();
