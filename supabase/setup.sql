-- =====================================================================
--  MARCHÉ — installation de la base de données Supabase
--  À coller EN ENTIER dans : Supabase > SQL Editor > New query > Run
--  (le script peut être relancé sans danger)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) TABLE DES ANNONCES
--    Les contrôles (longueurs, prix, catégories...) sont refaits ici,
--    car ceux du formulaire peuvent être contournés par un tiers.
--    Si tu ajoutes une catégorie dans data.dart, ajoute-la aussi
--    dans la liste category_id ci-dessous.
-- ---------------------------------------------------------------------
create table if not exists public.announcements (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  title         text not null check (char_length(title) between 5 and 80),
  description   text not null check (char_length(description) between 10 and 1000),
  price         numeric not null check (price > 0 and price < 100000000000),
  category_id   text not null check (category_id in (
                  'vehicules', 'immobilier', 'electronique', 'maison', 'mode',
                  'emploi', 'services', 'loisirs', 'bebe', 'animaux')),
  city          text not null check (char_length(city) between 1 and 60),
  contact_phone text not null check (char_length(contact_phone) between 6 and 20),
  type          text not null check (type in ('vente', 'achat')),
  photo_urls    text[] not null default '{}' check (cardinality(photo_urls) <= 5),
  created_at    timestamptz not null default now()
);

create index if not exists announcements_created_idx  on public.announcements (created_at desc);
create index if not exists announcements_owner_idx    on public.announcements (owner_id);
create index if not exists announcements_category_idx on public.announcements (category_id);


-- ---------------------------------------------------------------------
-- 2) SÉCURITÉ (Row Level Security)
--    - tout le monde peut LIRE les annonces
--    - on ne peut PUBLIER qu'en son propre nom
--    - on ne peut SUPPRIMER que ses propres annonces
--    - personne ne peut MODIFIER une annonce (l'appli n'en a pas besoin)
-- ---------------------------------------------------------------------
alter table public.announcements enable row level security;

drop policy if exists "annonces_lecture" on public.announcements;
create policy "annonces_lecture" on public.announcements
  for select to anon, authenticated
  using (true);

drop policy if exists "annonces_publication" on public.announcements;
create policy "annonces_publication" on public.announcements
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "annonces_suppression" on public.announcements;
create policy "annonces_suppression" on public.announcements
  for delete to authenticated
  using (owner_id = auth.uid());


-- ---------------------------------------------------------------------
-- 3) LIMITES ANTI-SPAM
--    30 annonces au maximum par utilisateur, 10 par période de 24 h.
--    Les messages commencent par "LIMITE:" : l'appli les affiche tels quels.
-- ---------------------------------------------------------------------
create or replace function public.check_announcement_limits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.announcements
        where owner_id = new.owner_id) >= 30 then
    raise exception 'LIMITE: vous avez atteint le maximum de 30 annonces. Supprimez-en une pour en publier une nouvelle.';
  end if;

  if (select count(*) from public.announcements
        where owner_id = new.owner_id
          and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'LIMITE: maximum 10 annonces par jour. Réessayez demain.';
  end if;

  return new;
end;
$$;

drop trigger if exists announcements_limits on public.announcements;
create trigger announcements_limits
  before insert on public.announcements
  for each row execute function public.check_announcement_limits();


-- ---------------------------------------------------------------------
-- 4) SIGNALEMENTS
--    Les utilisateurs peuvent signaler une annonce (une seule fois chacun)
--    mais NE PEUVENT PAS lire la table : toi seul la consultes, dans
--    Supabase > Table Editor > reports.
-- ---------------------------------------------------------------------
create table if not exists public.reports (
  id              uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  reporter_id     uuid not null default auth.uid()
                    references auth.users (id) on delete cascade,
  reason          text not null check (reason in ('arnaque', 'inapproprie')),
  created_at      timestamptz not null default now(),
  unique (announcement_id, reporter_id)
);

alter table public.reports enable row level security;

drop policy if exists "signalements_creation" on public.reports;
create policy "signalements_creation" on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid());


-- ---------------------------------------------------------------------
-- 5) STOCKAGE DES PHOTOS
--    Bucket public en lecture (les photos s'affichent par leur adresse).
--    Chaque utilisateur ne peut écrire / supprimer que dans SON dossier
--    (le premier niveau du chemin est son identifiant).
--    Limite : 2 Mo par photo, formats jpeg / png / webp.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "photos_envoi" on storage.objects;
create policy "photos_envoi" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- La suppression a aussi besoin du droit de lecture sur son propre dossier.
drop policy if exists "photos_lecture_proprietaire" on storage.objects;
create policy "photos_lecture_proprietaire" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "photos_suppression" on storage.objects;
create policy "photos_suppression" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
