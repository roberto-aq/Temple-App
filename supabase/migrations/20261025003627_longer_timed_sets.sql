-- Series por tiempo de hasta 3 horas.
--
-- `reps` guarda repeticiones o, en ejercicios por tiempo, segundos. El límite
-- anterior (300) cortaba el cardio en 5 minutos. La app sigue limitando las
-- repeticiones a 300; la base solo pone el tope de 3 horas (10 800 segundos).

alter table public.sets drop constraint sets_reps_check;
alter table public.sets
  add constraint sets_reps_check check (reps between 1 and 10800);
