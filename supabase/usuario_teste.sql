-- Provisione o acesso ao hospital de teste para um usuário já criado no Supabase Auth.
-- Antes de executar: troque o e-mail abaixo pelo e-mail exato da conta de teste.
-- Crie a conta em Supabase Dashboard > Authentication > Users > Add user.
-- Este script não define senha nem cria auth.users; isso deve ser feito pelo Auth.

do $$
declare
  email_teste text := 'teste.vittacare@example.com';
  nome_hospital text := 'Hospital de Teste VittaCare';
  usuario_teste uuid;
  hospital_teste uuid;
begin
  select id into usuario_teste
  from auth.users
  where lower(email) = lower(email_teste)
  limit 1;
  if usuario_teste is null then
    raise exception 'Não encontrei % em Authentication > Users. Crie primeiro a conta de teste no painel do Supabase.', email_teste;
  end if;

  -- Contas criadas pelo painel podem não ter os metadados usados pelo gatilho de cadastro.
  insert into public.perfis (
    id, nome_completo, correio_eletronico, idade, sexo,
    conselho, numero_conselho, versao_termos
  ) values (
    usuario_teste, 'Usuário de Teste VittaCare', email_teste, 30, 'outro',
    'CRM', 'TESTE-0001', '1.0'
  )
  on conflict (id) do nothing;

  select id into hospital_teste
  from public.hospitais
  where nome = nome_hospital
  limit 1;

  if hospital_teste is null then
    insert into public.hospitais (nome)
    values (nome_hospital)
    returning id into hospital_teste;
  end if;

  insert into public.vinculos_hospitalares (hospital_id, usuario_id, papel, ativo)
  values (hospital_teste, usuario_teste, 'admin', true)
  on conflict (hospital_id, usuario_id)
  do update set papel = excluded.papel, ativo = true;
end;
$$;

-- Confirme os registros criados:
select h.nome as hospital, u.email, v.papel, v.ativo
from public.vinculos_hospitalares v
join public.hospitais h on h.id = v.hospital_id
join auth.users u on u.id = v.usuario_id
where lower(u.email) = lower('teste.vittacare@example.com');
