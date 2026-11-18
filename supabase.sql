-- Plataforma Seltec · Faturas e Permutas
-- Cole tudo no SQL Editor do Supabase e clique em Run. Pode rodar de novo sem problema.

-- 1) Tabela única com todos os registros (clientes, faturas, ajustes, rotinas)
create table if not exists public.docs (
  path text primary key,
  colecao text not null,
  data jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid default auth.uid()
);
create index if not exists docs_colecao_idx on public.docs (colecao);
alter table public.docs replica identity full;

-- 2) Só quem tem login entra (ninguém de fora lê nem grava)
alter table public.docs enable row level security;
drop policy if exists "logados leem" on public.docs;
drop policy if exists "logados criam" on public.docs;
drop policy if exists "logados alteram" on public.docs;
drop policy if exists "logados apagam" on public.docs;
create policy "logados leem"    on public.docs for select to authenticated using (true);
create policy "logados criam"   on public.docs for insert to authenticated with check (true);
create policy "logados alteram" on public.docs for update to authenticated using (true) with check (true);
create policy "logados apagam"  on public.docs for delete to authenticated using (true);

-- 3) Atualização em tempo real entre as pessoas
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'docs') then
    alter publication supabase_realtime add table public.docs;
  end if;
end $$;

-- 4) Pasta privada para os PDFs (faturas e contas Cemig) e a logo
insert into storage.buckets (id, name, public) values ('arquivos', 'arquivos', false)
  on conflict (id) do nothing;
drop policy if exists "logados leem arquivos" on storage.objects;
drop policy if exists "logados enviam arquivos" on storage.objects;
drop policy if exists "logados apagam arquivos" on storage.objects;
create policy "logados leem arquivos"   on storage.objects for select to authenticated using (bucket_id = 'arquivos');
create policy "logados enviam arquivos" on storage.objects for insert to authenticated with check (bucket_id = 'arquivos');
create policy "logados apagam arquivos" on storage.objects for delete to authenticated using (bucket_id = 'arquivos');
