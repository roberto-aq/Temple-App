-- Unidad en que se anotó el peso de cada serie.
--
-- `kg` sigue guardando el peso en kilos; `unit` solo dice si la serie se
-- escribió en kilos o en libras, para mostrarla igual. Las series anteriores
-- quedan en kilos.

alter table public.sets
  add column unit text not null default 'kg' check (unit in ('kg', 'lb'));
