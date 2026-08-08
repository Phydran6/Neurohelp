-- Neurohelp – Grundschema
--
-- Grundsatz aus dem Konzept (Abschnitt 14): Nutzerdaten liegen LOKAL auf dem
-- Gerät. Serverseitig liegt nur, was zwingend zentral sein muss:
-- Benutzerkonto, Wiederherstellung, Reset-Mails.
--
-- Es gibt hier bewusst KEINE Tabellen für Historie, Aufgaben, Nachrichten
-- oder Kontakte. Wer sie hier ergänzt, bricht das Kernversprechen der App.

-- ---------------------------------------------------------------------------
-- Profile
-- ---------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint profiles_username_length check (char_length(username) between 3 and 32),
  constraint profiles_username_format check (username ~ '^[A-Za-z0-9_.-]+$')
);

create unique index profiles_username_lower_key
  on public.profiles (lower(username));

comment on table public.profiles is
  'Minimales Konto-Profil. Enthält bewusst keine Nutzerinhalte.';

-- ---------------------------------------------------------------------------
-- Wiederherstellungs-Codes (optional, Konzept Abschnitt 13)
-- ---------------------------------------------------------------------------

create table public.recovery_codes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  code_hash   text not null,
  created_at  timestamptz not null default now(),
  used_at     timestamptz
);

create index recovery_codes_user_id_idx on public.recovery_codes (user_id);

comment on column public.recovery_codes.code_hash is
  'Nur der Hash. Der Klartext-Code wird einmalig beim Einrichten angezeigt.';

-- ---------------------------------------------------------------------------
-- Row Level Security: jeder sieht ausschließlich seine eigenen Zeilen
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.recovery_codes enable row level security;

create policy "Eigenes Profil lesen"
  on public.profiles for select
  using ((select auth.uid()) = id);

create policy "Eigenes Profil ändern"
  on public.profiles for update
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "Eigene Wiederherstellungs-Codes lesen"
  on public.recovery_codes for select
  using ((select auth.uid()) = user_id);

create policy "Eigene Wiederherstellungs-Codes anlegen"
  on public.recovery_codes for insert
  with check ((select auth.uid()) = user_id);

create policy "Eigene Wiederherstellungs-Codes löschen"
  on public.recovery_codes for delete
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Automatik
-- ---------------------------------------------------------------------------

-- Profil beim Registrieren anlegen. Der Benutzername kommt aus den
-- Metadaten der Registrierung; ohne Angabe wird der Mail-Präfix genutzt.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'username', ''),
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- updated_at pflegen
create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();
