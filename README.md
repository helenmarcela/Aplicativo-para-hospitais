# Aplicativo-para-hospitais

## Conexão com Supabase

1. Execute [`supabase/schema.sql`](supabase/schema.sql) no SQL Editor do projeto Supabase. O gatilho cria `perfis` a partir dos metadados enviados no cadastro, inclusive quando a confirmação de e-mail está ativa.
2. Em `index.html`, substitua `SUPABASE_URL` e `SUPABASE_ANON_KEY` pela Project URL e pela chave publishable (ou anon) do projeto. A chave `service_role` nunca deve estar no navegador.
3. Sirva a pasta por um servidor HTTP local ou hospedagem estática e configure a URL da aplicação nas URLs de redirecionamento de autenticação do Supabase.
4. O login e cadastro usam Supabase Auth. O perfil vai para `public.perfis`; mensagens carregam e são inseridas em `public.mensagens_equipe`.
5. O cadastro não associa automaticamente a pessoa a um hospital. Um administrador ou processo confiável deve criar `hospitais` e `vinculos_hospitalares`. Sem vínculo ativo, a RLS bloqueia dados hospitalares e o envio de mensagens.

O painel clínico e os formulários de reserva ainda exibem dados de demonstração. A conexão implementada não grava pacientes, internações ou reservas: essas operações precisam ser ligadas aos registros reais e às tabelas correspondentes (`pacientes`, `internacoes`, `salas_cirurgicas`, `reservas_cirurgicas`) antes de usar essas telas com dados assistenciais.

Para preparar acesso de teste, crie primeiro a conta em Supabase Dashboard → Authentication → Users → Add user. Depois ajuste o e-mail em [`supabase/usuario_teste.sql`](supabase/usuario_teste.sql) e execute o arquivo no SQL Editor. Ele cria o perfil (se necessário), um hospital de teste e o vínculo ativo de administrador.
