-- VittaCare: esquema inicial para Supabase/PostgreSQL.
-- Aplicar em um projeto Supabase. Senhas pertencem exclusivamente a auth.users.
-- A associação de usuários a hospitais deve ser provisionada por fluxo confiável
-- (backend/service role ou convite aprovado), nunca por autoinscrição do cliente.

create extension if not exists pgcrypto;

create type public.conselho_profissional as enum ('CRM', 'COREN');
create type public.sexo_perfil as enum ('feminino', 'masculino', 'outro', 'prefiro-nao-informar');
create type public.papel_hospitalar as enum ('admin', 'medico', 'enfermeiro', 'auxiliar', 'profissional');
create type public.sexo_paciente as enum ('feminino', 'masculino', 'outro', 'nao_informado');
create type public.situacao_internacao as enum ('internado', 'alta', 'transferido', 'obito');
create type public.nivel_gravidade as enum ('estavel', 'atencao', 'grave', 'critico');
create type public.situacao_reserva as enum ('reservada', 'confirmada', 'em_andamento', 'concluida', 'cancelada');

create table public.hospitais (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  nome_completo text not null,
  correio_eletronico text not null,
  endereco text,
  idade smallint check (idade between 18 and 120),
  sexo public.sexo_perfil,
  conselho public.conselho_profissional not null,
  numero_conselho text not null,
  uf_conselho char(2), -- O formulário atual não coleta UF; tornar obrigatório após incluí-la na interface.
  termos_aceitos_em timestamptz not null default now(),
  versao_termos text not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (conselho, uf_conselho, numero_conselho)
);

create table public.vinculos_hospitalares (
  hospital_id uuid not null references public.hospitais(id) on delete cascade,
  usuario_id uuid not null references public.perfis(id) on delete cascade,
  papel public.papel_hospitalar not null default 'profissional',
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  primary key (hospital_id, usuario_id)
);

create table public.unidades (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitais(id) on delete cascade,
  nome text not null,
  tipo_unidade text,
  criado_em timestamptz not null default now(),
  unique (hospital_id, nome),
  unique (id, hospital_id)
);

create table public.leitos (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitais(id) on delete cascade,
  unidade_id uuid not null,
  numero_leito text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  foreign key (unidade_id, hospital_id) references public.unidades(id, hospital_id) on delete cascade,
  unique (unidade_id, numero_leito),
  unique (id, hospital_id)
);

create table public.pacientes (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitais(id) on delete cascade,
  numero_prontuario text not null,
  nome_completo text not null,
  data_nascimento date,
  sexo public.sexo_paciente not null default 'nao_informado',
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (hospital_id, numero_prontuario),
  unique (id, hospital_id)
);

create table public.internacoes (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitais(id) on delete cascade,
  paciente_id uuid not null,
  unidade_id uuid not null,
  leito_id uuid,
  situacao public.situacao_internacao not null default 'internado',
  gravidade public.nivel_gravidade not null default 'estavel',
  diagnostico text,
  internado_em timestamptz not null default now(),
  alta_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  foreign key (paciente_id, hospital_id) references public.pacientes(id, hospital_id),
  foreign key (unidade_id, hospital_id) references public.unidades(id, hospital_id),
  foreign key (leito_id, hospital_id) references public.leitos(id, hospital_id),
  unique (id, hospital_id)
);
create unique index internacoes_um_leito_ativo on public.internacoes(leito_id)
  where leito_id is not null and situacao = 'internado';
create index internacoes_painel_idx on public.internacoes(hospital_id, situacao, gravidade);

create table public.equipe_internacao (
  internacao_id uuid not null,
  hospital_id uuid not null,
  usuario_id uuid not null references public.perfis(id),
  funcao_equipe text not null check (funcao_equipe in ('medico_atual', 'enfermeiro_responsavel', 'auxiliar_enfermagem', 'outro')),
  atribuido_em timestamptz not null default now(),
  encerrado_em timestamptz,
  primary key (internacao_id, usuario_id, funcao_equipe),
  foreign key (internacao_id, hospital_id) references public.internacoes(id, hospital_id) on delete cascade
);

create table public.alergias (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  paciente_id uuid not null,
  substancia text not null,
  reacao text,
  observacoes text,
  registrado_por uuid references public.perfis(id),
  criado_em timestamptz not null default now(),
  foreign key (paciente_id, hospital_id) references public.pacientes(id, hospital_id) on delete cascade
);

create table public.prescricoes_medicamentos (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  internacao_id uuid not null,
  medicamento text not null,
  dose text not null,
  via_administracao text,
  horarios text,
  prescrito_por uuid not null references public.perfis(id),
  prescrito_em timestamptz not null default now(),
  instrucoes text,
  suspenso_em timestamptz,
  foreign key (internacao_id, hospital_id) references public.internacoes(id, hospital_id) on delete cascade
);

create table public.administracoes_medicamentos (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  prescricao_id uuid not null references public.prescricoes_medicamentos(id) on delete cascade,
  administrado_por uuid not null references public.perfis(id),
  administrado_em timestamptz not null default now(),
  situacao text not null check (situacao in ('administrado', 'omitido', 'recusado')),
  observacoes text,
  foreign key (hospital_id) references public.hospitais(id) on delete cascade
);

create table public.procedimentos (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  internacao_id uuid not null,
  descricao text not null,
  realizado_em timestamptz,
  registrado_por uuid not null references public.perfis(id),
  observacoes text,
  criado_em timestamptz not null default now(),
  foreign key (internacao_id, hospital_id) references public.internacoes(id, hospital_id) on delete cascade
);

create table public.anotacoes_clinicas (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  internacao_id uuid not null,
  anotacao text not null,
  autor_id uuid not null references public.perfis(id),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  foreign key (internacao_id, hospital_id) references public.internacoes(id, hospital_id) on delete cascade
);

create table public.salas_cirurgicas (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitais(id) on delete cascade,
  numero_sala text not null,
  especialidade text,
  ativo boolean not null default true,
  unique (hospital_id, numero_sala),
  unique (id, hospital_id)
);

create table public.reservas_cirurgicas (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  sala_cirurgica_id uuid not null,
  paciente_id uuid not null,
  internacao_id uuid,
  procedimento text not null,
  medico_responsavel_id uuid not null references public.perfis(id),
  inicio_em timestamptz not null,
  termino_em timestamptz,
  situacao public.situacao_reserva not null default 'reservada',
  criado_por uuid not null references public.perfis(id),
  criado_em timestamptz not null default now(),
  foreign key (sala_cirurgica_id, hospital_id) references public.salas_cirurgicas(id, hospital_id),
  foreign key (paciente_id, hospital_id) references public.pacientes(id, hospital_id),
  foreign key (internacao_id, hospital_id) references public.internacoes(id, hospital_id)
);
create index reservas_cirurgicas_horarios_idx on public.reservas_cirurgicas(hospital_id, sala_cirurgica_id, inicio_em);

create table public.mensagens_equipe (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitais(id) on delete cascade,
  autor_id uuid not null references public.perfis(id),
  mensagem text not null check (length(trim(mensagem)) > 0),
  criado_em timestamptz not null default now()
);
create index mensagens_equipe_recentes_idx on public.mensagens_equipe(hospital_id, criado_em desc);

-- RLS: nenhum usuário obtém acesso a dados clínicos sem associação ativa ao hospital.
-- Em produção, restrinja INSERT/UPDATE por papel e prefira RPCs para transições críticas.
create or replace function public.usuario_e_membro_hospital(hospital_alvo uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.vinculos_hospitalares m
    where m.hospital_id = hospital_alvo and m.usuario_id = (select auth.uid()) and m.ativo
  );
$$;
revoke all on function public.usuario_e_membro_hospital(uuid) from public;
grant execute on function public.usuario_e_membro_hospital(uuid) to authenticated;

alter table public.hospitais enable row level security;
alter table public.perfis enable row level security;
alter table public.vinculos_hospitalares enable row level security;
alter table public.unidades enable row level security;
alter table public.leitos enable row level security;
alter table public.pacientes enable row level security;
alter table public.internacoes enable row level security;
alter table public.equipe_internacao enable row level security;
alter table public.alergias enable row level security;
alter table public.prescricoes_medicamentos enable row level security;
alter table public.administracoes_medicamentos enable row level security;
alter table public.procedimentos enable row level security;
alter table public.anotacoes_clinicas enable row level security;
alter table public.salas_cirurgicas enable row level security;
alter table public.reservas_cirurgicas enable row level security;
alter table public.mensagens_equipe enable row level security;

create policy "membros podem consultar o proprio hospital" on public.hospitais for select to authenticated
  using (public.usuario_e_membro_hospital(id));
create policy "usuario consulta o proprio perfil" on public.perfis for select to authenticated using (id = (select auth.uid()));
create policy "usuario atualiza o proprio perfil" on public.perfis for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "membros consultam vinculos hospitalares" on public.vinculos_hospitalares for select to authenticated
  using (public.usuario_e_membro_hospital(hospital_id));

create policy "membros do hospital acessam unidades" on public.unidades for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam leitos" on public.leitos for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam pacientes" on public.pacientes for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam internacoes" on public.internacoes for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam equipe de internacao" on public.equipe_internacao for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam alergias" on public.alergias for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam prescricoes de medicamentos" on public.prescricoes_medicamentos for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam administracoes de medicamentos" on public.administracoes_medicamentos for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam procedimentos" on public.procedimentos for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam anotacoes clinicas" on public.anotacoes_clinicas for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam salas cirurgicas" on public.salas_cirurgicas for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital acessam reservas cirurgicas" on public.reservas_cirurgicas for all to authenticated
  using (public.usuario_e_membro_hospital(hospital_id)) with check (public.usuario_e_membro_hospital(hospital_id));
create policy "membros do hospital consultam mensagens" on public.mensagens_equipe for select to authenticated
  using (public.usuario_e_membro_hospital(hospital_id));
create policy "membros enviam suas proprias mensagens" on public.mensagens_equipe for insert to authenticated
  with check (public.usuario_e_membro_hospital(hospital_id) and autor_id = (select auth.uid()));
