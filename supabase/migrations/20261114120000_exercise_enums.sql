-- Tipo de registro y grupo muscular de los ejercicios propios como enums.
--
-- Así el editor de tablas de Supabase muestra una lista para elegir en vez de
-- texto libre. La app no cambia: envía y lee los valores como texto.
--
-- Los valores y su orden son los de la app: ExerciseKind (lib/models/models.dart)
-- y muscleGroups (lib/data/catalog.dart).
--
-- IMPORTANTE: antes de publicar una versión de la app con un grupo muscular o
-- tipo nuevo, agrega el valor aquí con otra migración, por ejemplo:
--   alter type public.muscle_group add value 'gluteos' after 'piernas';
-- Si no, el servidor rechaza el ejercicio y la app lo descarta al sincronizar.
--
-- Si algún ejercicio tiene un valor que no está en la lista, la migración falla
-- sin cambiar nada. Para revisarlo antes:
--   select distinct kind, muscle_group from public.exercises;

create type public.exercise_kind as enum ('weight', 'reps', 'seconds');

create type public.muscle_group as enum (
  'pecho',
  'espalda',
  'hombros',
  'biceps',
  'triceps',
  'antebrazo',
  'piernas',
  'pantorrillas',
  'core',
  'cardio'
);

alter table public.exercises drop constraint exercises_kind_check;

alter table public.exercises
  alter column kind type public.exercise_kind
    using kind::public.exercise_kind,
  alter column muscle_group type public.muscle_group
    using muscle_group::public.muscle_group;
